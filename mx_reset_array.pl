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
use ArrayExpress::Curator::Common qw(
    date_now 
    mprint 
    check_linebreaks 
    ae2_load_dir_for_acc
    print_adf_header
    make_magetab_adf_header_from_design_info
);

require ArrayExpress::AutoSubmission::DB::ArrayDesign;
use ArrayExpress::MXExport::General qw(get_mx_file_path);
use ArrayExpress::MXExport::ArrayDesign;
use ArrayExpress::ADFParser::ArrayDesignInfo;
use ArrayExpress::ADFParser::MIAMExpress_ADF;
use ArrayExpress::ADFParser::MAGETAB_ADF;

use ArrayExpress::ADFParser::ADFConvert qw(
                  add_dbs_to_header
                  get_mx_to_magetab_mapping                 
                  process_header 
                  process_lines
                  process_magetab_header_db_tags
                  print_adf
                  $VERSION
                  );


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

          -e   export in MAGE-TAB format to AE2_LOAD directory without re-checking
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

sub create_MXExport_array_design_get_mx_design_info {
    
    # From the MX submission ID, create the MXExport ArrayDesign object, 
    # which has array_info (of class ADFParser/ArrayDesignInfo.pm) as one 
    # of its attributes.
    # $mx_design_info object is the value of the "array_info" attribute, 
    # storing all the meta data associated with the ADF from the 
    # MIAMExpress submissions database.        

    my ($subid) = @_;
    my ($design, $mx_design_info);
    
    eval{
        $design = ArrayExpress::MXExport::ArrayDesign->new({
            subid => $subid,
        });
        
        $mx_design_info = $design->get_array_info;
        
    };

    if ($@){
      	my $error = "Could not get array design information. Error: $@";
       	update_sub_tracking($subid, $CONFIG->get_STATUS_CRASHED, $error);
       	die $error;
    }
    return ($design, $mx_design_info);
}    


sub create_mx_adf_parser {
    my ($adf_path, $design_info) = @_;
    print "Creating a MIAMExpress ADF parser...\n";
    my $parser = ArrayExpress::ADFParser::MIAMExpress_ADF->new({
		    adf_path   => $adf_path,
		    composites => undef,
		    accession  => 'na',
		    output     => undef,
		    target     => '.',
		    namespace  => '',
		    heading_regex => $CONFIG->get_MX_ADF_REGEX, 
		    array_info => $design_info,
    });
    return $parser;
}

sub create_mtab_adf_parser {
    my ($adf_path, $design_info) = @_;
    print "Creating a MAGE-TAB ADF parser...\n";
    my $parser = ArrayExpress::ADFParser::MAGETAB_ADF->new({
		    adf_path   => $adf_path,
		    composites => undef,
		    accession  => 'na',
		    output     => undef,
		    target     => '.',
		    namespace  => '',
		    heading_regex => $CONFIG->get_MAGETAB_ADF_REGEX,
		    array_info => $design_info,
    });    
    return $parser;
}    


sub export_array{

    my ($array, $adf_path, $design_info, $from_magetab, $parser)  = @_;
    ref($array) eq 'ArrayExpress::AutoSubmission::DB::ArrayDesign'
        or die "Error: first argument passed to export_array must be an ArrayExpress::AutoSubmission::DB::ArrayDesign object. This is a ".ref($array)."\n";
    
    my $subid = $array->miamexpress_subid;
    my $accession = $array->get_accession
        or die "Error: no array accession available for submission $subid";
    my $name = $array->name
        or die "Error: no array design name available for submission $subid";
    
    # Convert mac to unix - MX ADF export can't handle mac line endings
    mac2unix($adf_path);    
   
    # When we're doing force/manual export, no parser object is passed
    # to this method. We'll have to generate either a MX or a MTAB parser,
    # depending on the format of the file we're exporting from.  
 
    if (!$parser && !$from_magetab){
        $parser = create_mx_adf_parser($adf_path, $design_info);
    } elsif (!$parser && $from_magetab){
        $parser = create_mtab_adf_parser($adf_path, $design_info);
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
    
    # Now do the actual export. Warn again about array design info being taken
    # exclusively from the MIAMExpress form!
    my $start = date_now;     		
    my $magetab_path;
    update_sub_tracking($array->miamexpress_subid, $CONFIG->get_STATUS_AE2_EXPORT);

    my $meta_data_warning = "*** Warning: ADF export takes array design info meta-data ONLY from the MIAMExpress form!\n";
    print STDOUT $meta_data_warning;
    print $export_log_fh $meta_data_warning;
    
    if ($parser->is_nimblegen){   		
        $magetab_path = export_ndf_magetab($accession, $adf_path, $design_info, $export_log_fh);
    }
    else{   		
    	$magetab_path = export_array_magetab($accession, $adf_path, $design_info, $export_log_fh, $from_magetab);
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
    
   
    return;
}

sub export_ndf_magetab{

    my ($accession, $adf_path, $design_info, $export_log_fh, $export_from_format) = @_;

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
    
    my ($acc, $adf_path, $mx_design_info, $export_log_fh, $from_magetab) = @_;
	
    my $output = File::Spec->catfile(ae2_load_dir_for_acc($acc), $acc.".adf.txt");
	
    mprint (*STDOUT, $export_log_fh, date_now." - MAGE-TAB exporting $adf_path to $output\n");
    
    # $header_info_ref is a simple hash holding mage-tab formatted meta-data header,
    # hash key = ADF tag, hash value = actual meta data:
	
    my $header_info_ref = make_magetab_adf_header_from_design_info($mx_design_info);
   	
    open (my $adf_fh, "<", $adf_path) 
        or die "Error: Could not open $adf_path for reading - $!";

    if ( $from_magetab == 0 ) {
        my %adf_tag = get_mx_to_magetab_mapping();

        # get column headings and process all remaining lines, identify empty cols
        # process_lines separates column headings from the meat of the ADF
        
        my ($heading_line, $all_lines_fh, $value_count_ref) 
            = process_lines($adf_fh, $CONFIG->get_MX_ADF_REGEX);

        # process_header changes MX column headings to corresponding MAGE-TAB ones:
        
        my ($keepers_count_ref, $new_headings_ref, $dbs_used_ref) 
            = process_header($heading_line, \%adf_tag, $value_count_ref);

        # Add some extra info to header that we gathered while parsing ADF body
        add_dbs_to_header($header_info_ref, $dbs_used_ref);

        open (my $fh, ">", $output) 
            or die "Error: Could not open $output for writing - $!";

        print_adf(
                fh              => $fh, 
                headers_ref     => $new_headings_ref, 
                lines_fh        => $all_lines_fh, 
                keepers_ref     => $keepers_count_ref, 
                delim           => "\t",
                header_info_ref => $header_info_ref,
              ); 

     } elsif ( $from_magetab == 1 ) {
         
         # If the user's submission was in MAGE-TAB format, we take the
         # meta-data from the MIAMExpress form, not the meta-data in the
         # ADF's header (even if there is one)
         
         # Also, the ADF's column headings are isolated to look for 
         # names of external DBs, because we need to add Term Source
         # information in the meta-data for these DBs

         # The column headings and content of the ADF are not modified.
         
         my ($heading_line, $all_lines_fh, $value_count_ref)
            = process_lines($adf_fh, $CONFIG->get_MAGETAB_ADF_REGEX);
  
         my ($keepers_count_ref, $unmod_headings_ref, $dbs_used_ref) 
            = process_magetab_header_db_tags($heading_line);
        
         add_dbs_to_header($header_info_ref, $dbs_used_ref);
         
         open (my $fh, ">", $output) 
            or die "Error: Could not open $output for writing - $!";
         
         print_adf(
                fh              => $fh, 
                headers_ref     => $unmod_headings_ref,
                lines_fh        => $all_lines_fh,
                keepers_ref     => $keepers_count_ref,
                delim           => "\t",
                header_info_ref => $header_info_ref,
              ); 
    }
   
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

sub detect_mtab_format{
    my ($adf_path) = @_;  
    my $is_magetab = 0;
        
    # We use MX regex to test as well because "Reporter Name" 
    # in the MAGE-TAB regex is common to both MX and MAGE-TAB 
    # formats. Using the MAGE-TAB regex alone will match ADFs
    # of both formats and is_magetab will always be true
    
    my $mx_column_heading_regex = $CONFIG->get_MX_ADF_REGEX;
    my $mtab_column_heading_regex = $CONFIG->get_MAGETAB_ADF_REFEX;

    open (my $file, "<", $adf_path) or croak("Error: unable to open file $adf_path: $!");

    # Only check the first 100 lines of the file so we don't try to look for headers
    # throughout the entire file (some ADFs have thousands of rows!)

    LINE: foreach my $line (<$file>){
        last LINE if $. == 100;
        if ($line =~ m/($mx_column_heading_regex)/) {
            print "ADF is in MIAMExpress format.\n";
            last LINE;
        } elsif ($line =~ m/($mtab_column_heading_regex)/) {
            $is_magetab = 1;
            print "ADF is in MAGE-TAB format.\n";
            last LINE;
        }
    }
    close $file;
    return $is_magetab;
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
        
        # Attempt to get array design meta data (design_info). Meta data are info
        # entered on the MIAMExpress webform as well as the submitter's personal details
        
        my ($design, $mx_design_info) = create_MXExport_array_design_get_mx_design_info($subid);
        $mx_design_info->set_accession($accession);

        my $adf_path = $mx_design_info->get_adf_path;
        my $report = $adf_path.".report";
                                            
        my $parser;

        print "Starting ADF checking for $accession. ADF: $adf_path..\n";
        my $start_time = time;
        
        # Convert mac to unix - MX ADF export can't handle mac line endings
        mac2unix($adf_path);

        # Distinguish between MIAMExpress and MTAB ADFs here by checking the column headings
        my $is_magetab = detect_mtab_format($adf_path); 

        if ($is_magetab) {
            $parser = create_mtab_adf_parser($adf_path, $mx_design_info);
        } else {
            $parser = create_mx_adf_parser($adf_path, $mx_design_info);
        }
        
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
        
        # Attempt to run automatic export as checking has passed
        eval{
            export_array($array, $adf_path, $mx_design_info, $is_magetab, $parser);
        };
        if ($@){
            update_sub_tracking($subid, $CONFIG->get_STATUS_EXPORT_ERROR, "Array export failed with error: $@");
        }
        else{
            update_sub_tracking($subid, $CONFIG->get_STATUS_COMPLETE);
        }
    } 

      
    # If the "-e" option is called directly, then we manually/forcibly export the ADF

    if ($args->{export}){
        reset_mx_tsubmis($subid, 'C');
        
        my $array = update_sub_tracking($subid, "Starting export");
              
        my ($design, $mx_design_info) = create_MXExport_array_design_get_mx_design_info($subid);
        $mx_design_info->set_accession($array->get_accession);

        my $adf = $mx_design_info->get_adf_path;
        my $is_magetab = detect_mtab_format($adf); 

        # Now call export_array to do manual export
        eval{
            export_array($array, $adf, $mx_design_info, $is_magetab);
        };
        if ($@){
        	update_sub_tracking($subid, $CONFIG->get_STATUS_EXPORT_ERROR, "Array export failed with error: $@");
        }
        else{
            update_sub_tracking($subid, $CONFIG->get_STATUS_COMPLETE);       
        }
    }
}
