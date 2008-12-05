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

use ArrayExpress::Curator::Config qw($CONFIG);
use ArrayExpress::Curator::Common qw(date_now);
require ArrayExpress::AutoSubmission::DB::ArrayDesign;
use ArrayExpress::MXExport::General qw(get_mx_file_path);
use ArrayExpress::MXExport::ArrayDesign;
use ArrayExpress::ADFParser::ArrayDesignInfo;
use ArrayExpress::ADFParser::MIAMExpress_ADF;

########
# SUBS #
########

sub parse_args {

    my %args;

    GetOptions(
	    "p|pending" => \$args{pending},
        "c|check"   => \$args{check},
        "e|export"  => \$args{export},
    );

    unless ( ( $args{pending} || $args{check} || $args{export} ) && @ARGV) {
        print <<"NOINPUT";
Usage: $PROGRAM_NAME <option> <list of submission ids>

Options:  -c   re-check submission
                 (sets MIAMExpress submission status to "C").

          -e   export MAGE-ML without re-checking
                 (sets MIAMExpress submission status to "C").

          -p   set submission to pending status for user editing

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
        die(      "Error: SubID $subid returns invalid "
                . "number of MIAMExpress arrays: $count\n" );
    }

    my $name = $results->[0][0];
    my $login = $results->[0][1];

    $array->set(
        status              => $status,
        date_last_processed => date_now(),
        name                => $name,
        miamexpress_login   => $login, 
        comment             => $comment, 
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
        or die "Error: first argument passed to export_array must be an ArrayExpress::AutoSubmission::DB::ArrayDesign object\n";
    
    my $subid = $array->miamexpress_subid;
    my $accession = $array->get_accession
        or die "Error: no array accession available for submission $subid";
    my $name = $array->name
        or die "Error: no array design name available for submission $subid";
    my $export_script = $CONFIG->get_MX_ARRAY_MAGEML_EXPORT_COMMAND
        or die "Error: array MAGEML export command not provided in Config file";
        
    
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
		    heading_regex => qr{ 
		         \b(Meta\s*Column|Reporter\s*Identifier|Composite\s*Sequence\s*Identifier)\b 
		                     }ixms, 
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
    my $miame_score = $parser->get_miame_score;
    print "MIAME score: $miame_score\n";
    my $dw_score = $parser->get_dw_score;
    print "Data warehouse score: $dw_score\n";
    $array->set( 
        miame_score          => $miame_score,
        data_warehouse_ready => $dw_score,
    );
    $array->update;
                  
    my $command = "$export_script '$name' $accession";
    my $time = date_now;
    print $export_log_fh "\n$time - Starting MAGEML export using command:\n$command\n";
    my $status = system ($command);
    $time = date_now;
    if ($status == 0){
        print $export_log_fh "$time - MAGEML export completed\n";
    }
    else{
        print $export_log_fh "$time - MAGEML export failed: $?\n";
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
    
    move ($xml, $target_path)
        or die "Error: could not move mageml from $xml to $target_path - $!";
    
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
        update_sub_tracking($subid, $CONFIG->get_STATUS_CHECKING);
        
        my $design = ArrayExpress::MXExport::ArrayDesign->new({
            subid => $subid,
        });
        my $design_info = $design->get_array_info;
        
        my $adf = $design_info->get_adf_path;
        my $report = $adf.".report";

        my $parser;
        
        print "Starting ADF checking for $adf..\n";
        my $start_time = time;

		# Create a MIAMExpress ADF parser
		print "Creating MIAMExpress ADF parser..\n";
		$parser = ArrayExpress::ADFParser::MIAMExpress_ADF->new({
		    adf_path   => $adf,
		    composites => undef ,
		    accession  => 'na',
		    output     => undef,
		    target     => '.',
		    namespace  => '',
		    heading_regex => qr{ 
		         \b(Meta\s*Column|Reporter\s*Identifier|Composite\s*Sequence\s*Identifier)\b 
		                     }ixms, 
		    array_info => $design_info,
		});
        
        eval{
	        $parser->check({ 
		        log_file_path => $report
		    });
            
        };
        if($@){
            update_sub_tracking($subid, $CONFIG->get_STATUS_CRASHED, "ADF checking crashed with error: $@");
            die "ADF checking crashed with error: $@";
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
            
        # export if checks pass
        my $array = update_sub_tracking($subid, $CONFIG->get_STATUS_EXPORT);
        
        if ($parser->get_warning_status){
            print "Checker result: WARNINGS - see checker log\nproceeding to export\n";
            my $new = File::Spec->catfile( 
                                   $CONFIG->get_AUTOSUBMISSIONS_ARRAY_TARGET, 
                                   "MEXP", 
                                   $array->get_accession,
                                   "CHECKER_WARNINGS.log",
                                   );
            close $parser->get_log_fh;
            copy ($report, $new);
            chmod 0777, $new;
        }
        else{
            print "Checker result: PASS\n";
        }
        
        eval{
            export_array($array, $adf, $design_info, $parser);
        };
        if ($@){
            update_sub_tracking($subid, $CONFIG->get_STATUS_EXPORT_ERROR, "Array MAGEML generation failed with error: $@");
        }
        else{
            update_sub_tracking($subid, $CONFIG->get_STATUS_COMPLETE);
        }
    }
    
    if ($args->{export}){
        reset_mx_tsubmis($subid, 'C');
        
        # export
        my $array = update_sub_tracking($subid, $CONFIG->get_STATUS_EXPORT);
        
        my $design = ArrayExpress::MXExport::ArrayDesign->new({
            subid => $subid,
        });
        my $design_info = $design->get_array_info;
        eval{
            export_array($array, $design_info->get_adf_path, $design_info); 
        };
        if ($@){
        	update_sub_tracking($subid, $CONFIG->get_STATUS_EXPORT_ERROR, "Array MAGEML generation failed with error: $@");
        }
        else{
            update_sub_tracking($subid, $CONFIG->get_STATUS_COMPLETE);       
        }
    }
}