#!/usr/bin/env perl
#
# Script to reset a Tab2MAGE experiment submission to pending, and
# marking it for checking upon resubmission.
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use Getopt::Long;
use English qw( -no_match_vars );
use Readonly;

use ArrayExpress::Curator::Config qw($CONFIG);

use ArrayExpress::Curator::Common qw(date_now);
use ArrayExpress::AutoSubmission::DB;

Readonly my $CURATION => 1;
Readonly my $PENDING  => 0;

########
# SUBS #
########

sub reset_accession_cache {

    my ( $id, $expt_type, $status, $in_curation ) = @_;

    my @experiments
        = ArrayExpress::AutoSubmission::DB::Experiment->search_like(
	    id              => $id,
	    experiment_type => $expt_type,
	    is_deleted      => 0,
	);

    if ( scalar @experiments == 1 ) {

	my $experiment = $experiments[0];

        $experiment->set(
            status              => $status,
            date_last_processed => date_now(),
            curator             => getlogin,
	    in_curation         => $in_curation,
            comment             => (
                $experiment->status() eq $CONFIG->get_STATUS_CRASHED()
                ? q{}
                : undef
            ),
        );
	$experiment->update();
        printf STDOUT (
            qq{Accession table successfully updated (%s_%i set to "%s").\n},
	    $experiment->experiment_type(),
	    $experiment->id(),
	    $experiment->status(),
        );
	if ( $in_curation ) {
	    print STDOUT (qq{Experiment is in curation.\n});
	}
	else {
	    print STDOUT (qq{Experiment is pending.\n});
	}
    }
    elsif ( scalar @experiments > 1 ) {
        print STDERR (
            "Error: Multiple $expt_type submissions with ID $id found in accession table. Skipping.\n"
        );
    }
    else {
        print STDERR (
            "Error: No $expt_type submission with ID $id found in accession table. Skipping.\n"
        );
    }
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
Usage: $PROGRAM_NAME <option> <list of submission directories>

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

SUBMISSION:
foreach my $dirname (@ARGV) {

    my ( $expt_type, $id ) = ($dirname =~ m/\A (.+) \_ (\d+) \z/xms);

    unless ( $expt_type && $id ) {
	warn("Error: cannot parse directory name $dirname. Skipping.\n");
	next SUBMISSION;
    }

    if ( $args->{export} ) {
        reset_accession_cache(
	    $id,
	    $expt_type,
	    $CONFIG->get_STATUS_PASSED(),
	    $CURATION,
	);
    }
    elsif ( $args->{check} ) {
        reset_accession_cache(
	    $id,
	    $expt_type,
	    $CONFIG->get_STATUS_PENDING(),
	    $CURATION,
	);
    }
    elsif ( $args->{pending} ) {
        reset_accession_cache(
	    $id,
	    $expt_type,
	    $CONFIG->get_STATUS_PENDING(),
	    $PENDING,
	);
    }
    else {
	die("Error: Unrecognised user option.");
    }
}

print STDOUT ("Done.\n\n");

exit 0;

