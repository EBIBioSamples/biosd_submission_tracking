#!/usr/bin/perl --
#
# Script to generate QC stats for Affy CEL files. Note that the CelQC
# module requires the R executable to be on your path; you may also
# need to set $R_LIBS to point to a suitable library directory, since
# Affy annotation libraries will be automatically downloaded by R as
# appropriate.
#
# N.B. the first line of this script needs to point to the perl interpreter.
#
# $Id$

use strict;
use warnings;

# NOTE: no "use lib" placeholder for this script, because it uses a
# PATH specific to the LSF cluster which is maintained in the shell
# wrapper for this script.

use Getopt::Long;
use Benchmark;

use ArrayExpress::Tracking::CelQC;
use ArrayExpress::Curator::Common qw(date_now);

########
# SUBS #
########

sub parse_args {

    my ( $identifier, $celfile, $quiet, $delete_cel, $want_help );

    GetOptions(
	"i|identifier=s" => \$identifier,
	"f|file=s"       => \$celfile,
	"q|quiet"        => \$quiet,
	"d|delete"       => \$delete_cel,
	"h|help"         => \$want_help,
    );

    if ( $want_help || ! defined $celfile ) {
	print <<"USAGE";

    Usage: $0 -f <cel file>

    Options: -i  BioAssayData identifier, used to update the record in
                   the tracking database.

             -q  Suppress output, e.g. as part of a cron job.

             -d  Delete CEL file upon completion (also used as part of a cron job).

USAGE

	exit 255;
    }
    unless ( -r $celfile ) {
	die(qq{Error: CEL file "$celfile" does not exist or is unreadable.\n});
    }

    return ( $identifier, $celfile, $quiet, $delete_cel );
}

sub create_record {

    my ( $loaded_data, $key, $value ) = @_;

    require ArrayExpress::AutoSubmission::DB::QualityMetric;
    require ArrayExpress::AutoSubmission::DB::Platform;

    if ( lc( $key ) eq 'platform' ) {

	# Platform is a special case.
	my $platform = ArrayExpress::AutoSubmission::DB::Platform->find_or_create({
	    name => $value,
	});
	$loaded_data->set('platform_id', $platform);
	$loaded_data->update();
    }
    else {

	# Everything else goes in quality_metrics. At the moment this
	# is constrained to decimal type.
	my $qm = ArrayExpress::AutoSubmission::DB::QualityMetric->find_or_create({
	    type => $key,
	});

	my $qm_instances = $loaded_data->quality_metric_instances(
	    quality_metric_id => $qm,
	);
	return if ( scalar $qm_instances );

	$loaded_data->add_to_quality_metrics({
	    loaded_data_id    => $loaded_data,
	    quality_metric_id => $qm,
	    value             => $value,
	    date_calculated   => date_now(),
	});
    }

    return;
}

########
# MAIN #
########

my ( $identifier, $celfile, $quiet, $delete_cel ) = parse_args();

my $loaded_data;
if ( $identifier ) {

    require ArrayExpress::AutoSubmission::DB::LoadedData;

    my @data = ArrayExpress::AutoSubmission::DB::LoadedData->search(
	identifier => $identifier,
	is_deleted => 0,
    );
    unless ( scalar @data ) {
	die(qq{Error: identifier "$identifier" not found in tracking DB});
    }

    $loaded_data = $data[0];

    unless ( $loaded_data->needs_metrics_calculation() ) {
	die(qq{Loaded data "$identifier" needs no metrics calculation.\n});
    }
}

my $starttime = new Benchmark;

my $qc = ArrayExpress::Tracking::CelQC->new({
    input  => $celfile,
    quiet  => $quiet,
});

# This may fail, in which case it will croak().
my $result;
eval { $result = $qc->run_metrics() };
if ( $@ ) {

    # Failure.
    print("Error calculating metrics: $@");
}
else {

    # Success.
    my $endtime = new Benchmark;
    my $timediff = timediff( $endtime, $starttime );
    print STDOUT ( "\nTotal run time = ", timestr($timediff), "\n\n", );

    if ( $loaded_data ) {

	# Write the results to the database.
	RESULT:
	while ( my ( $key, $value ) = each %{ $result } ) {
	    create_record( $loaded_data, $key, $value );
	}
    }
    else {

	foreach my $key (sort keys %$result) {
	    print STDOUT (join("\t", $key, $result->{$key}), "\n");
	}
    }
}

if ( $loaded_data ) {

    # Set our loaded_data as having had metrics calculation (or at
    # least an attempt therof).
    $loaded_data->set('needs_metrics_calculation', 0);
    $loaded_data->update();
}

# Delete the cel file if we've been told to.
if ( $delete_cel ) {
    unlink($celfile) or die("Error deleting CEL file: $!");
}

