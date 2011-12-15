#!/usr/bin/env perl
#
# Script to reset a MIAMExpress array submission to pending, or
# check and export it
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use DBI;
use Getopt::Long;
use English qw( -no_match_vars );
use Readonly;
use File::Spec;
use File::Copy qw(move copy);
use Sys::Hostname;

use ArrayExpress::Curator::Config qw($CONFIG);
use ArrayExpress::Curator::Common qw(date_now mprint check_linebreaks ae2_load_dir_for_acc);
require ArrayExpress::AutoSubmission::DB::ArrayDesign;
use ArrayExpress::MXExport::General qw(get_mx_file_path);
use ArrayExpress::MXExport::ArrayDesign;
use ArrayExpress::ADFParser::ArrayDesignInfo;
use ArrayExpress::ADFParser::MIAMExpress_ADF;

use ArrayExpress::ADFParser::ADFConvert qw(
                  add_dbs_to_header
                  get_mx_to_magetab_mapping 
                  get_magetab_adf_header
                  make_magetab_adf_header_from_design_info
                  process_header 
                  process_lines 
                  print_adf
                  print_adf_header
                  $VERSION
                  );

# Global variables to switch magetab and mageml export on and off
my $EXPORT_MAGETAB = 1;
my $EXPORT_MAGEML = 0;

# FIXME: This script is getting long. Methods should be factored out
# into an array exporter class.

########
# SUBS #
########

sub parse_args {

    my %args;

    GetOptions(
	    "p|pending" => \$args{pending},
        "c|check"   => \$args{check},
        "e|export"  => \$args{export},
        "m|magetab" => \$args{magetab},
    );

    unless ( ( $args{pending} || $args{check} || $args{export} ) && @ARGV) {
        print <<"NOINPUT";
Usage: $PROGRAM_NAME <option> <list of submission ids>

Options:  -c   re-check submission
                 (sets MIAMExpress submission status to "C").

          -e   export MAGE-ML without re-checking
                 (sets MIAMExpress submission status to "C").

          -p   set submission to pending status for user editing
          
          -m   export MAGE-TAB to AE2 load directory.
                 (temporary option to allow curator controlled AE2 export during 
                 AE2 testing phase)

NOINPUT

        exit 255;
    }

    return \%args;

}

sub get_mx_dbh{
	
    unless ( $CONFIG->get_MX_DSN() ) {
        warn(     "Warning: MX_DSN constant not set. "
                . "No connection made to MIAMExpress database." );
        return;
    }

    my $dbh = DBI->connect(
        $CONFIG->get_MX_DSN(),      $CONFIG->get_MX_USERNAME(),
        $CONFIG->get_MX_PASSWORD(), $CONFIG->get_MX_DBPARAMS()
        )
        or die("Database connection error: $DBI::errstr\n");
    
    return $dbh;    
}

sub reset_mx_tsubmis{
    my ($subid, $new_status)= @_;
    
    my $dbh = get_mx_dbh;

    my $sth = $dbh->prepare(<<'QUERY');
select distinct TSUBMIS_SYSUID, TSUBMIS_PROC_STATUS
from TSUBMIS, TARDESIN
where TSUBMIS_SYSUID=?
and TSUBMIS_SYSUID=TARDESIN_SUBID
and TSUBMIS_DEL_STATUS='U'
and TARDESIN_DEL_STATUS='U'
QUERY

    $sth->execute($subid) or die("$sth->errstr\n");
    my $results = $sth->fetchall_hashref('TSUBMIS_SYSUID');
    $sth->finish();

    my $count = scalar( grep { defined $_ } values %$results );

    unless ( $count == 1 ) {
        die(      "Error: SubID $subid returns invalid "
                . "number of MIAMExpress arrays: $count\n" );
    }

    my $old_status = $results->{$subid}{'TSUBMIS_PROC_STATUS'}
        or warn("Warning: MIAMExpress TSUBMIS_PROC_STATUS is empty.\n");

    $sth = $dbh->prepare(<<'QUERY');
update TSUBMIS set TSUBMIS_PROC_STATUS=?
where TSUBMIS_SYSUID=?
and TSUBMIS_DEL_STATUS='U'
QUERY

    $sth->execute( $new_status, $subid ) or die("$sth->errstr\n");
    $sth->finish();

    $dbh->disconnect()
        or die( "Database disconnection error: " . $dbh->errstr() . "\n" );

    print STDOUT ( "MIAMExpress TSUBMIS table successfully updated "
            . "($subid: changed from $old_status to $new_status).\n" );

    return;    
}

sub update_sub_tracking{

	my ($subid, $status, $comment) = @_;

	my $array = ArrayExpress::AutoSubmission::DB::ArrayDesign->find_or_create({
	            miamexpress_subid => $subid,
	            is_deleted => 0,
	            });
    
    my $dbh = get_mx_dbh;

    my $sth = $dbh->prepare(<<'QUERY');
select TARDESIN_DESIGN_NAME, TSUBMIS_LOGIN
from TARDESIN, TSUBMIS
where TSUBMIS_SYSUID=?
and TSUBMIS_SYSUID=TARDESIN_SUBID
and TSUBMIS_DEL_STATUS='U'
and TARDESIN_DEL_STATUS='U'
QUERY
    $sth->execute($subid) or die("$sth->errstr\n");
    my $results = $sth->fetchall_arrayref;

    my $count = scalar( @$results );   
    unless ( $count == 1 ) {
    	# Write reason for failure to subs tracking
    	my $error = "Error: SubID $subid returns invalid "
                  . "number of MIAMExpress arrays: $count";
                  
    	$array->set(
    	     status              => $CONFIG->get_STATUS_CRASHED,
    	     date_last_processed => date_now(),
    	     comment             => $error, 
    	);
    	$array->update();
    	
    	# then die
        die $error;
    }

    my $name = $results->[0][0];
    my $login = $results->[0][1];

    my %args = (
        status              => $status,
        date_last_processed => date_now(),
        name                => $name,
        miamexpress_login   => $login, 
    );
    $args{comment}=$comment if $comment;
    
    $array->set(
       %args
    ); 

    $array->update();
    print STDOUT (
       qq{Accession table successfully updated ($subid set to "$status").\n}
    );   
    return $array;
}

sub export_array{

    my ($array, $adf_path, $design_info, $parser)  = @_;
    ref($array) eq 'ArrayExpress::AutoSubmission::DB::ArrayDesign'
        or die "Error: first argument passed to export_array must be an ArrayExpress::AutoSubmission::DB::ArrayDesign object. This is a ".ref($array)."\n";
    
    my $subid = $array->miamexpress_subid;
    my $accession = $array->get_accession
        or die "Error: no array accession available for submission $subid";
    my $name = $array->name
        or die "Error: no array design name available for submission $subid";
    
    # Convert mac to unix - MX ADF export can't handle mac line endings
    mac2unix($adf_path);    
    
    if (!$parser){
        # create one for mx and dw checking
        print "Creating MIAMExpress ADF parser..\n";
		$parser = ArrayExpress::ADFParser::MIAMExpress_ADF->new({
		    adf_path   => $adf_path,
		    composites => undef ,
		    accession  => 'na',
		    output     => undef,
		    target     => '.',
		    namespace  => '',
		    heading_regex => $CONFIG->get_MX_ADF_REGEX, 
		    array_info => $design_info,
		});
    }
   
    # set up the export log file (replacing checker log)
    my $export_log = "$adf_path.export";
    $parser->set_log_file_path($export_log);
    open(my $export_log_fh, ">", $export_log)
       or die "Error: could not open export log $export_log: $!";  
    $parser->set_log_fh($export_log_fh);
    chmod 0777, $export_log;
       
    # Compute and store MIAME and DW scores  
    my ($miame_score, $dw_score);
    eval{ $miame_score = $parser->get_miame_score; };
    print "MIAME score: $miame_score\n";
    eval{ $dw_score = $parser->get_dw_score; };
    print "Data warehouse score: $dw_score\n";
    $array->set( 
        miame_score          => $miame_score,
        data_warehouse_ready => $dw_score,
    );
    $array->update;
    
    if ($EXPORT_MAGETAB){
    	my $start = date_now;     		
    	my $magetab_path;
    	update_sub_tracking($array->miamexpress_subid, $CONFIG->get_STATUS_AE2_EXPORT);
    	if ($parser->is_nimblegen){   		
    		$magetab_path = export_ndf_magetab($accession, $adf_path, $design_info, $export_log_fh);
    	}
    	else{   		
    		$magetab_path = export_array_magetab($accession, $adf_path, $design_info, $export_log_fh);
    	}
    	my $end = date_now;
    	
    	if($magetab_path){
    		$array->set( 
    		    file_to_load => $magetab_path,
    		    migration_status => "Exported directly to AE2",
    		);
    		$array->update;
    	}

        $array->add_to_events({
			event_type       => 'AE2 Export',
			was_successful   => ( $magetab_path ? 1 : 0 ),
			source_db        => "MIAMExpress",
			start_time       => $start,
			end_time         => $end,
			machine          => hostname(),
			operator         => getlogin(),
			log_file         => $export_log,
			is_deleted       => 0,
		});
    }
    
    if ($EXPORT_MAGEML){
    	my $start = date_now;	
    	update_sub_tracking($array->miamexpress_subid, $CONFIG->get_STATUS_EXPORT);
    	
    	# We need to export mageml for both standard and NDF submissions
        my $xml_path = export_array_mageml($accession, $adf_path, $name, $export_log_fh, $parser);
        
        # Check if it is a Nimblegen design file (NDF)
        if ($parser->is_nimblegen){
    	    $xml_path = export_ndf_mageml($accession, $adf_path, $export_log_fh, $xml_path);
            $array->set(
        	    comment => "NDF converted to ADF.",
            );
            $array->update;       
        }
        my $end = date_now;
        
        $array->add_to_events({
			event_type       => 'MAGE-ML export',
			was_successful   => ( $xml_path ? 1 : 0 ),
			source_db        => "MIAMExpress",
			start_time       => $start,
			end_time         => $end,
			machine          => hostname(),
			operator         => getlogin(),
			log_file         => $export_log,
			is_deleted       => 0,
		});
    }
    
    return;
}

sub export_array_mageml{

    my ($accession, $adf_path, $name, $export_log_fh, $parser) = @_;
        
    my $export_script = $CONFIG->get_MX_ARRAY_MAGEML_EXPORT_COMMAND
        or die "Error: array MAGEML export command not provided in Config file";
        
    # Run array mageml export script              
    my $command = "$export_script '$name' $accession";
    my $time = date_now;
    mprint (*STDOUT, $export_log_fh, "$time - Starting MAGEML export using command:\n$command\n");
    my $status = system ($command);
    $time = date_now;
    if ($status == 0){
        mprint (*STDOUT, $export_log_fh, "$time - MAGEML export completed\n");
    }
    else{
        print $export_log_fh, "$time - MAGEML export failed: $?\n";
        die "MAGEML export failed: $?";
    }
    
    # Move mageml to target directory
    my $target_dir = File::Spec->catdir( $CONFIG->get_AUTOSUBMISSIONS_ARRAY_TARGET, "MEXP", $accession );
    my $xml = $adf_path.".xml";
    my $target_path = File::Spec->catfile($target_dir, $accession.".xml");
    
    if (! -e $target_dir){
        mkdir ($target_dir, 0777)
            or die "Error: could not make target directory $target_dir - $!";
    }
    chmod 0777, $target_dir;     

    move ($xml, $target_path)
        or die "Error: could not move mageml from $xml to $target_path - $!";
    
    return $target_path;
}

sub export_ndf_mageml{
	
	my ($accession, $adf_path, $export_log_fh, $target_path) = @_;
	
	my ($vol, $target_dir, $file) = File::Spec->splitpath($target_path);
    my $new_name = $accession.".adf.txt";
    my $adf_target_path = File::Spec->catfile($target_dir,$new_name);
     		
    # Convert NDF to ADF and copy to load dir
    my $conversion_complete = run_ndf_converter($adf_path, $adf_target_path, $export_log_fh);
    	
    mprint (*STDOUT, $export_log_fh, date_now." - Removing FeatureGroups_assnlist from mageml\n");    
    # Remove FeatureGroups_assnlist from mageml
    my $new_xml = $target_path.".new";
    open (my $in_fh, "<", $target_path)
        or die ("Could not open $target_path to remove FeatureGroups_assnlist: $!");
    open (my $out_fh, ">", $new_xml)
        or die ("Could not open $new_xml for writing: $!");
        
    my $in_featuregroup_assnlist = 0;    
    while (<$in_fh>){
        $in_featuregroup_assnlist = 1 if /<FeatureGroups_assnlist>/;
        print $out_fh $_ unless $in_featuregroup_assnlist;
        $in_featuregroup_assnlist = 0 if /<\/FeatureGroups_assnlist>/;
    }
    close $in_fh;
    close $out_fh;
        
    # Backup original xml file
    my $xml_bak = $target_path.".bak";
    move($target_path, $xml_bak)
        or die "Could not move $target_path to $xml_bak: $!";
    chmod 0777, $xml_bak;
        
    # Move new file to target xml file path
    move($new_xml, $target_path)
        or die "Could not move $new_xml to $target_path: $!";
    chmod 0777, $target_path;
    mprint (*STDOUT, $export_log_fh, date_now." - FeatureGroups_assnlist removed\n");

    unless($conversion_complete){
    	return undef;
    }
        
    return $target_path; 
}

sub export_ndf_magetab{

    my ($accession, $adf_path, $design_info, $export_log_fh) = @_;

    my $final_adf = File::Spec->catfile(ae2_load_dir_for_acc($accession), $accession.".adf.txt");

    mprint (*STDOUT, $export_log_fh, date_now." - MAGE-TAB exporting $adf_path to $final_adf\n");
        
    # Make header
    $design_info->set_pol_type_atts({value => "DNA"});
    my $header_info = make_magetab_adf_header_from_design_info($design_info);
    
    # Convert NDF to magetab ADF   
    my $tmp_adf = File::Spec->catfile(ae2_load_dir_for_acc($accession), $accession.".tmp");
    my $conversion_complete = run_ndf_converter($adf_path, $tmp_adf, $export_log_fh);
    
    unless($conversion_complete){
    	return undef;
    }
    
    # Add header to converted file	
    mprint (*STDOUT, $export_log_fh, date_now." - Adding header to file $final_adf\n");
    open (my $fh, ">", $final_adf)
        or die "Error: Could not open $final_adf for writing - $!";
    
    print_adf_header($header_info, $fh, "\t");
    open (my $tmp_fh, "<", $tmp_adf)
        or die "Error: Could not open $tmp_adf for reading - $!";
    while(<$tmp_fh>){
    	print $fh $_;
    }
    close $tmp_fh;
    unlink $tmp_adf;

    mprint (*STDOUT, $export_log_fh, date_now." - MAGE-TAB export complete\n");
      
    return $final_adf;
}

sub run_ndf_converter{
	
	my ($ndf, $adf, $export_log_fh) = @_;
	
    my $ndf_convert = $CONFIG->get_NDF_CONVERT_SCRIPT;
    my $command = "$ndf_convert '$ndf'";
    my $time = date_now;
    mprint (*STDOUT, $export_log_fh, "$time - Converting NDF to ADF format using command:\n$command\n");
    my $status = system($command);
    	
    if ($status == 0){
    	my $adf_file = $ndf.".adf";
    	mprint (*STDOUT, $export_log_fh, date_now." - NDF to ADF conversion completed\n");
    	move($adf_file, $adf)
    	    or die "Error: could not move $adf_file to $adf - $!";
    	chmod 0777, $adf;
    	mprint (*STDOUT, $export_log_fh, date_now." - ADF moved to $adf\n");
    }
    else{
        print $export_log_fh date_now." - NDF to ADF conversion failed: $?\n";
        return 0;
    }
    
    return 1;
}

sub export_array_magetab{
	my ($acc, $adf_path, $design_info, $export_log_fh) = @_;
	
	my $output = File::Spec->catfile(ae2_load_dir_for_acc($acc), $acc.".adf.txt");
	
	mprint (*STDOUT, $export_log_fh, date_now." - MAGE-TAB exporting $adf_path to $output\n");
	
	my $header_info_ref = make_magetab_adf_header_from_design_info($design_info);
	
    my %adf_tag = get_mx_to_magetab_mapping();
    open (my $adf_fh, "<", $adf_path) 
        or die "Error: Could not open $adf_path for reading - $!";

    # get header and process all remaining lines, identify empty cols
    
    # FIXME: in future if we fail to identify MX headings we should
    # look for MAGETAB ADF headings and if found simply insert
    # ADF header info and then copy file to AE2 load dir
    my ($heading_line, $all_lines_fh, $value_count_ref) 
        = process_lines($adf_fh, $CONFIG->get_MX_ADF_REGEX);

    my ($keepers_ref, $new_headings_ref, $dbs_used_ref) 
        = process_header($heading_line, \%adf_tag, $value_count_ref);

    # Add some extra info to header that we gathered while parsing ADF body
    add_dbs_to_header($header_info_ref, $dbs_used_ref);

    open (my $fh, ">", $output) 
        or die "Error: Could not open $output for writing - $!";

    print_adf(
            fh              => $fh, 
            headers_ref     => $new_headings_ref, 
            lines_fh        => $all_lines_fh, 
            keepers_ref     => $keepers_ref, 
            delim           => "\t",
            header_info_ref => $header_info_ref,
          ); 
   
   mprint (*STDOUT, $export_log_fh, date_now." - MAGE-TAB export complete\n");
   
   return $output;   
}

sub mac2unix{
	my ($file) = @_;
	
	my ($counts, $le) = check_linebreaks($file);
	
	if ($counts->{mac}){
		print "Converting mac line endings to unix for file $file\n";
		my @args = ('/usr/bin/perl','-i','-pe','s/\r/\n/g',$file);
	    system (@args) == 0
	        or die "system @args failed: $?";
	}
	return;
}

########
# MAIN #
########
umask 002;
my $args = parse_args();

foreach my $subid (@ARGV) {
	            
    # Perform requested action
    if ($args->{pending}){
        reset_mx_tsubmis($subid, 'P');
        update_sub_tracking($subid, $CONFIG->get_STATUS_PENDING);
    }
    
    if ($args->{check}){
        reset_mx_tsubmis($subid, 'C');
        
        # Run checker
        my $array = update_sub_tracking($subid, $CONFIG->get_STATUS_CHECKING);
        my $accession = $array->get_accession;
        
        # Attempt to get array design info from MX (need ADF file path)
        my $design_info;
        eval{
            my $design = ArrayExpress::MXExport::ArrayDesign->new({
                subid => $subid,
            });
            $design_info = $design->get_array_info;
        };
        if ($@){
        	my $error = "Could not get array design information. Error: $@";
        	update_sub_tracking($subid, $CONFIG->get_STATUS_CRASHED, $error);
        	die $error;
        }

        $design_info->set_accession($accession);
        
        my $adf = $design_info->get_adf_path;
        my $report = $adf.".report";

        my $parser;
        
        print "Starting ADF checking for $accession. ADF: $adf..\n";
        my $start_time = time;
        
        # Convert mac to unix - MX ADF export can't handle mac line endings
        mac2unix($adf);

		# Create a MIAMExpress ADF parser
		print "Creating MIAMExpress ADF parser..\n";
		$parser = ArrayExpress::ADFParser::MIAMExpress_ADF->new({
		    adf_path   => $adf,
		    composites => undef ,
		    accession  => 'na',
		    output     => undef,
		    target     => '.',
		    namespace  => '',
		    heading_regex => $CONFIG->get_MX_ADF_REGEX, 
		    array_info => $design_info,
		});
        
        # Attempt to check ADF file
        eval{
	        $parser->check({ 
		        log_file_path => $report
		    });
            
        };
        if($@){
            update_sub_tracking($subid, $CONFIG->get_STATUS_CRASHED, "ADF checking crashed with error: $@");
            die "ADF checking crashed with error: $!";
        }
        
        my $time_taken = time - $start_time; 
        print "Checks took $time_taken seconds\n";
                
        # chmod report file so it can be deleted
        my $mode = 0777;
        chmod $mode, $report;

        if ($parser->get_error_status){
            update_sub_tracking($subid, $CONFIG->get_STATUS_FAILED);
            print "Checker result: ERRORS\n";
            exit;
        }
                
        if ($parser->get_warning_status){
            print "Checker result: WARNINGS - see checker log\nproceeding to export\n";
            my $new = File::Spec->catfile( 
                                   $CONFIG->get_AUTOSUBMISSIONS_ARRAY_TARGET, 
                                   "MEXP", 
                                   $accession,
                                   "CHECKER_WARNINGS.log",
                                   );
            close $parser->get_log_fh;
            copy ($report, $new);
            chmod 0777, $new;
        }
        else{
            print "Checker result: PASS\n";
        }
        
        # Attempt to run mageml export
        eval{
            export_array($array, $adf, $design_info, $parser);
        };
        if ($@){
            update_sub_tracking($subid, $CONFIG->get_STATUS_EXPORT_ERROR, "Array export failed with error: $@");
        }
        else{
            update_sub_tracking($subid, $CONFIG->get_STATUS_COMPLETE);
        }
    }
    
    if ($args->{magetab}){
        # Change export option variables and then export
        $EXPORT_MAGETAB = 1;
        $EXPORT_MAGEML = 0;
        $args->{export} = 1;	
    }
    
    if ($args->{export}){
        reset_mx_tsubmis($subid, 'C');
        
        my $array = update_sub_tracking($subid, "Starting export");
        
        # Attempt to get array design info from MX for use in export command
        my $design_info;
        eval{
            my $design = ArrayExpress::MXExport::ArrayDesign->new({
                subid => $subid,
            });
            $design_info = $design->get_array_info;
        };
        if ($@){
        	my $error = "Could not get array design information. Error: $@";
        	update_sub_tracking($subid, $CONFIG->get_STATUS_CRASHED, $error);
        	die $error;
        }
        
        $design_info->set_accession($array->get_accession);
        
        # Attempt to run MIAMExpress mageml generation script
        eval{
            export_array($array, $design_info->get_adf_path, $design_info); 
        };
        if ($@){
        	update_sub_tracking($subid, $CONFIG->get_STATUS_EXPORT_ERROR, "Array export failed with error: $@");
        }
        else{
            update_sub_tracking($subid, $CONFIG->get_STATUS_COMPLETE);       
        }
    }
}
