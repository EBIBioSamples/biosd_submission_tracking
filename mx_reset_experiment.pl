#!/usr/bin/env perl
#
# Script to reset a MIAMExpress experiment submission to pending, and
# marking it for checking upon resubmission.
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

use ArrayExpress::Curator::Config qw($CONFIG);
use ArrayExpress::Curator::Common qw(date_now mx2tab);
require ArrayExpress::AutoSubmission::DB::Experiment;

Readonly my $EXPT_TYPE => 'MIAMExpress';
Readonly my $CURATION  => 1;
Readonly my $PENDING   => 0;

########
# SUBS #
########

sub reset_mx_tsubmis {

    my ( $subid, $new_status ) = @_;

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

    my $sth = $dbh->prepare(<<'QUERY');
select distinct TSUBMIS_SYSUID, TSUBMIS_PROC_STATUS
from TSUBMIS, TEXPRMNT
where TSUBMIS_SYSUID=?
and TSUBMIS_SYSUID=TEXPRMNT_SUBID
and TSUBMIS_DEL_STATUS='U'
and TEXPRMNT_DEL_STATUS='U'
QUERY

    $sth->execute($subid) or die("$sth->errstr\n");
    my $results = $sth->fetchall_hashref('TSUBMIS_SYSUID');
    $sth->finish();

    my $count = scalar( grep { defined $_ } values %$results );

    unless ( $count == 1 ) {
        die(      "Error: SubID $subid returns invalid "
                . "number of MIAMExpress experiments: $count\n" );
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

sub reset_accession_cache {

    my ( $subid, $status, $in_curation, $experiment_type ) = @_;

    # In future this will be a MAGE-TAB experiment that we reset to MIAMExpress.
    my @experiments
        = ArrayExpress::AutoSubmission::DB::Experiment->search(
	    miamexpress_subid => $subid,
	    is_deleted        => 0,
	);

    if ( scalar @experiments == 1 ) {

	my $expt = $experiments[0];

	# Sometimes submissions are forced to export; we handle the
	# requisite MX to MAGE-TAX export here.
	if ( $status eq $CONFIG->get_STATUS_PASSED()
		 && $expt->experiment_type() eq 'MIAMExpress' ) {
	    mx2tab($expt);
	}

	$experiment_type ||= $expt->experiment_type();

        $expt->set(
            status              => $status,
            date_last_processed => date_now(),
            curator             => getlogin,
	    in_curation         => $in_curation,
	    experiment_type     => $experiment_type,
            comment             => (
                $expt->status() eq $CONFIG->get_STATUS_CRASHED()
                ? q{}
                : $expt->comment()
            ),
        );
	$expt->update();
        print STDOUT (
            qq{Accession table successfully updated ($subid set to "$status").\n}
        );
    }
    elsif ( scalar @experiments > 1 ) {
	warn (
	    "Warning: Duplicate records found for SubID $subid in"
		. " experiments table. Please fix and re-run this script.\n"
	);
    }
    else {
        warn (
            "Warning: No submission with SubID $subid found in experiments table.\n"
        );
    }

    return;
}

sub parse_args {

    my %args;

    GetOptions(
	"p|pending" => \$args{pending},
        "c|check"   => \$args{check},
        "q|quick"   => \$args{quick},
        "e|export"  => \$args{export},
    );

    unless ( ( $args{pending} || $args{check} || $args{quick} || $args{export} ) && @ARGV) {
        print <<"NOINPUT";
Usage: $PROGRAM_NAME <option> <list of submission ids>

Options:  -c   set submission for full re-checking
                 (sets experiment back to "MIAMExpress", checks database annotation and data files).

          -q   set submission for quick re-checking
                 (checks experiment as indicated by its current type;
                    typically this will run annotation-only checks on MX MAGE-TAB experiments).

          -e   set submission for MAGE-ML export without re-checking
                 (experiment is exported according to its current type).

          -p   set submission to pending status for user editing
                 (sets experiment back to "MIAMExpress").

NOINPUT

        exit 255;
    }

    return \%args;

}

########
# MAIN #
########

my $args = parse_args();

foreach my $subid (@ARGV) {

    if ( $args->{export} ) {

        reset_mx_tsubmis( $subid, 'C' );
        reset_accession_cache(
	    $subid,
	    $CONFIG->get_STATUS_PASSED(),
	    $CURATION,
	);
    }
    elsif ( $args->{quick} ) {

        reset_mx_tsubmis( $subid, 'C' );
        reset_accession_cache(
	    $subid,
	    $CONFIG->get_STATUS_PENDING(),
	    $CURATION,
	);
    }
    elsif ( $args->{check} ) {

        reset_mx_tsubmis( $subid, 'C' );
        reset_accession_cache(
	    $subid,
	    $CONFIG->get_STATUS_PENDING(),
	    $CURATION,
	    $EXPT_TYPE,
	);
    }
    elsif ( $args->{pending} ) {

        reset_mx_tsubmis( $subid, 'P' );
        reset_accession_cache(
	    $subid,
	    $CONFIG->get_STATUS_PENDING(),
	    $PENDING,
	    $EXPT_TYPE,
	);
    }
    else {
	die("Error: Unrecognised user option.");
    }
}

print STDOUT ("Done.\n\n");

exit 0;

