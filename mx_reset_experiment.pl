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

use ArrayExpress::Curator::Common qw(date_now);
use ArrayExpress::AutoSubmission::DB;

Readonly my $EXPT_TYPE => 'MIAMExpress';

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

    my ( $subid, $status ) = @_;

    my $experiment
        = ArrayExpress::AutoSubmission::DB::Experiment->retrieve(
	    miamexpress_subid => $subid,
	    experiment_type   => $EXPT_TYPE,
	    is_deleted        => 0,
	);

    if ( $experiment ) {

        $experiment->set(
            status              => $status,
            date_last_processed => date_now(),
            curator             => getlogin,
            comment             => (
                $experiment->status() eq $CONFIG->get_STATUS_CRASHED()
                ? q{}
                : undef
            ),
        );
	$experiment->update();
        print STDOUT (
            qq{Accession table successfully updated ($subid set to "$status").\n}
        );
    }
    else {
        print STDERR (
            "Warning: No submission with SubID $subid found in accession table.\n"
        );
    }

    return;
}

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

Options:  -c   set submission for immediate re-checking
          -e   set submission for MAGE-ML export without re-checking
          -p   set submission to pending status for user editing

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
        reset_accession_cache( $subid, $CONFIG->get_STATUS_PASSED() );
    }
    elsif ( $args->{check} ) {

        reset_mx_tsubmis( $subid, 'C' );
        reset_accession_cache( $subid, $CONFIG->get_STATUS_PENDING() );
    }
    elsif ( $args->{pending} ) {

        reset_mx_tsubmis( $subid, 'P' );
        reset_accession_cache( $subid, $CONFIG->get_STATUS_PENDING() );
    }
    else {
	die("Error: Unrecognised user option.");
    }
}

print STDOUT ("Done.\n\n");

exit 0;

