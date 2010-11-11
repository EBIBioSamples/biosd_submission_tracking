#!/usr/bin/env perl
#
# Script to populate the tracking database with information from the
# ArrayExpress repository and data warehouse DB instances. The plan is
# to incorporate elements of this code into a regular update
# mechanism, running every 30 minutes or so. We also want a mechanism
# for wiping all the imported data indiscriminately and repopulating.
#
# $Id$

use strict;
use warnings;

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use Getopt::Long;
use Carp;
use List::Util qw(first);

require ArrayExpress::AutoSubmission::DB::Experiment;
require ArrayExpress::AutoSubmission::DB::ArrayDesign;
require ArrayExpress::AutoSubmission::DB::Organism;
require ArrayExpress::AutoSubmission::DB::Factor;
require ArrayExpress::AutoSubmission::DB::QuantitationType;
require ArrayExpress::AutoSubmission::DB::Event;

require ArrayExpress::Tracking::Event;
require ArrayExpress::Tracking::QueryHandler;

sub update_toplevel_objects {

    my ( $aedb ) = @_;

    print STDOUT "Inserting new experiment records...\n";
    my $ae_experiments = $aedb->get_experiments();
    my @prev_expts = ArrayExpress::AutoSubmission::DB::Experiment->search(
	is_deleted => 0,
    );
    my @prev_expt_accns = map { $_->accession() } @prev_expts;

    EXPT:
    foreach my $accession ( @$ae_experiments ) {

	# Don't load obviously bad accessions.
	next EXPT unless ( $accession =~ m/\A E-[A-Z]{4}-\d+[a-zA-Z]* \z/xms );

	unless ( first { defined($_) && $_ eq $accession } @prev_expt_accns ) {
	    my $expt = ArrayExpress::AutoSubmission::DB::Experiment->find_or_create({
		accession  => $accession,
		is_deleted => 0,
	    });
	    unless ( $expt->experiment_type() ) {
		$expt->set(
		    experiment_type => 'Unknown',
		);
		$expt->update();
	    }
	}
    }
    print STDOUT "Inserting new array design records...\n";
    my $ae_arrays = $aedb->get_array_designs();
    my @prev_arrays = ArrayExpress::AutoSubmission::DB::ArrayDesign->search(
	is_deleted => 0,
    );
    my @prev_array_accns = map { $_->accession() } @prev_arrays;

    ARRAY:
    foreach my $accession ( @$ae_arrays ) {

	# Don't load obviously bad accessions.
	next ARRAY unless ( $accession =~ m/\A A-[A-Z]{4}-\d+[a-zA-Z]* \z/xms );

	unless ( first { defined($_) && $_ eq $accession } @prev_array_accns ) {
	    ArrayExpress::AutoSubmission::DB::ArrayDesign->find_or_create({
		accession  => $accession,
		is_deleted => 0,
	    });
	}
    }

    return;
}

sub delete_cached_data {

    my ( $aedb, $todo ) = @_;

    # The aedb query object contains information on what *can* be
    # repopulated - and therefore deleted here.

    # Delete all events associated with the database instances of interest.
    if ( $todo->{events} ) {
	foreach my $instance ( @{ $aedb->get_instances() } ) {
	    print STDOUT ("Deleting old event data imported from $instance...\n");

	    # FIXME consider trying this without using the iterator
	    # approach? It might be faster.
	    ArrayExpress::AutoSubmission::DB::Event->search(
		target_db => $instance,
	    )->delete_all();
	}
    }

    # Delete metadata associated with experiments, array designs.
    if ( $todo->{metadata} ) {
	delete_cached_metadata( $aedb );
    }

    return;
}

sub delete_cached_metadata {

    my ( $aedb ) = @_;

    # Don't delete expt species (or anything else) for experiments not
    # loaded... but then how to mark these as being updateable upon
    # loading?

    # Experiments.
    my $ae_experiments = $aedb->get_experiments();

    my $expt_iterator = ArrayExpress::AutoSubmission::DB::Experiment->search(
	is_deleted => 0,
    );

    EXPT:
    while ( my $expt = $expt_iterator->next() ) {
	next EXPT unless ( first { $_ eq $expt->accession() } @$ae_experiments );

	printf STDOUT ("Deleting metadata for %s...\n", $expt->accession());

	# Setting release_date = undef is particularly important, sinc
	# it is used to flag objects needing update.
	$expt->set(
	    submitter_description   => undef,
	    curated_name            => undef,
	    num_samples             => undef,
	    num_hybridizations      => undef,
	    has_raw_data            => undef,
	    has_processed_data      => undef,
	    release_date            => undef,
	    is_released             => undef,
	    ae_miame_score          => undef,
	    ae_data_warehouse_score => undef,
	);

	$expt->array_design_instances()->delete_all();
	$expt->organism_instances()->delete_all();
	$expt->factor_instances()->delete_all();
	$expt->quantitation_type_instances()->delete_all();
	
	$expt->update();
    }

    # Array Designs.
    my $ae_arrays = $aedb->get_array_designs();

    my $array_iterator = ArrayExpress::AutoSubmission::DB::ArrayDesign->search(
	is_deleted => 0,
    );

    EXPT:
    while ( my $array = $array_iterator->next() ) {
	next EXPT unless ( first { $_ eq $array->accession() } @$ae_arrays );

	printf STDOUT ("Deleting metadata for %s...\n", $array->accession());

	# Setting release_date = undef is particularly important, sinc
	# it is used to flag objects needing update.
	$array->set(
	    release_date            => undef,
	    is_released             => undef,
	);

	$array->organism_instances()->delete_all();
	
	$array->update();
    }

    return;
}

sub update_events {

    my ( $object, $aedb ) = @_;

    # $object can be an experiment or array_design.

    unless ( $object->accession() ) {
	croak("Error: update_events called with an invalid experiment object (no accession).");
    }

    # N.B. we *do* process unloaded objects here.

    my $events = $aedb->get_events( $object->accession() );

    foreach my $event ( @{ $events } ) {
	$object->add_to_events({
	    event_type       => $event->get_event_type(),
	    was_successful   => $event->get_success(),
	    source_db        => $event->get_source_db(),
	    target_db        => $event->get_target_db(),
	    start_time       => $event->get_starttime(),
	    end_time         => $event->get_endtime(),
	    machine          => $event->get_machine(),
	    operator         => $event->get_operator(),
	    log_file         => $event->get_log_file(),
	    jobregister_dbid => $event->get_jobregister_dbid(),
	    comment          => $event->get_comment(),
	    is_deleted       => 0,
	});
    }

    return;
}

sub update_expt_metadata {

    my ( $expt, $aedb ) = @_;

    # FIXME not implemented: ae_data_warehouse_score.

    my $acc = $expt->accession();

    unless ( $acc ) {
	croak("Error: update_expt_metadata called with an invalid experiment object (no accession).");
    }

    # Don't process unloaded experiments.
    return unless ( $aedb->get_is_loaded( $acc ) );

    my $has_metadata = $expt->release_date();

    # Always update the date info, as it will change.
    $expt->set(
	release_date => ( $aedb->get_release_date($acc) || 0 ),
    );
    $expt->set(
	is_released => $aedb->get_is_released($acc),
    );
    $expt->set(
	in_data_warehouse => $aedb->get_expt_in_data_warehouse($acc),
    );

    unless ( $expt->curated_name() ) {
	$expt->set(
	    curated_name => $aedb->get_curated_name($acc),
	);
    }

    # Skip metadata update for experiments having a release date (this
    # is a fairly arbitrary shortcut to reduce processing time).
    unless ( defined $has_metadata ) {
	update_heavy_expt_queries( $expt, $aedb );
    }

    # Save any changes.
    $expt->update();

    return;
}

sub update_heavy_expt_queries {

    my ( $expt, $aedb ) = @_;

    my $acc = $expt->accession();

    unless ( $acc ) {
	croak("Error: update_heavy_expt_queries called with an invalid experiment object (no accession).");
    }

    # Only update the following if the metadatum is not present.
    unless ( defined ($expt->submitter_description()) ) {
	$expt->set(
	    submitter_description => $aedb->get_submitter_description($acc),
	);
    }
    unless ( defined ($expt->num_samples()) ) {
	$expt->set(
	    num_samples => $aedb->get_num_samples($acc),
	);
    }
    unless ( defined ($expt->num_hybridizations()) ) {
	$expt->set(
	    num_hybridizations => $aedb->get_num_hybridizations($acc),
	);
    }
    unless ( defined ($expt->has_raw_data()) ) {
	$expt->set(
	    has_raw_data => $aedb->get_has_raw_data($acc),
	);
    }
    unless ( defined ($expt->has_processed_data()) ) {
	$expt->set(
	    has_processed_data => $aedb->get_has_processed_data($acc),
	);
    }
    unless ( defined ($expt->ae_miame_score()) ) {
	$expt->set(
	    ae_miame_score => $aedb->get_ae_miame_score($acc),
	);
	# FIXME: should get_ae_minseqe_score from AE2 but nowhere
	# in subs tracking db to write it to yet
    }

    # FIXME where do we even get this from?
#    unless ( defined ($expt->ae_data_warehouse_score()) ) {
#	$expt->set(
#	    ae_data_warehouse_score => $aedb->get_ae_data_warehouse_score($acc),
#	);
#    }
    unless ( scalar ($expt->organisms()) ) {
	my $species_list = $aedb->get_expt_species($acc);
	foreach my $species ( @$species_list ) {
	    next unless defined ( $species );
	    my $organism = ArrayExpress::AutoSubmission::DB::Organism->find_or_create({
		scientific_name => $species,
		is_deleted      => 0,
	    });
	    $expt->add_to_organism_instances({
		experiment_id => $expt,
		organism_id   => $organism,
	    });
	}
    }
    unless ( scalar ($expt->factors()) ) {
	my $factor_list = $aedb->get_expt_factors($acc);
	foreach my $factor_name ( @$factor_list ) {
	    next unless defined ( $factor_name );
	    my $factor = ArrayExpress::AutoSubmission::DB::Factor->find_or_create({
		name       => $factor_name,
		is_deleted => 0,
	    });
	    $expt->add_to_factor_instances({
		experiment_id => $expt,
		factor_id     => $factor,
	    });
	}
    }
    unless ( scalar ($expt->quantitation_types()) ) {
	my $qt_list = $aedb->get_expt_qts($acc);
	foreach my $qt_name ( @$qt_list ) {
	    next unless defined ( $qt_name );
	    my $qt = ArrayExpress::AutoSubmission::DB::QuantitationType->find_or_create({
		name       => $qt_name,
		is_deleted => 0,
	    });
	    $expt->add_to_quantitation_type_instances({
		experiment_id        => $expt,
		quantitation_type_id => $qt,
	    });
	}
    }
    unless ( scalar ($expt->array_designs()) ) {
	my $array_list = $aedb->get_expt_arrays($acc);
	foreach my $array_acc ( @$array_list ) {
	    next unless defined ( $array_acc );
	    my $array_design = ArrayExpress::AutoSubmission::DB::ArrayDesign->find_or_create({
		accession  => $array_acc,
		is_deleted => 0,
	    });
	    $expt->add_to_array_design_instances({
		experiment_id   => $expt,
		array_design_id => $array_design,
	    });
	}
    }

    # Save any changes.
    $expt->update();

    return;
}

sub update_array_metadata {

    my ( $array, $aedb ) = @_;

    # FIXME not implemented: annotation_source, annotation_version, biomart_table_name.

    my $acc = $array->accession();

    unless ( $acc ) {
	croak("Error: update_array_metadata called with an invalid array design object (no accession).");
    }

    # Don't process unloaded array_designs.
    return unless ( $aedb->get_is_loaded( $acc ) );

    my $has_metadata = $array->release_date();

    $array->set(
	release_date => ( $aedb->get_release_date($acc) || 0 ),
    );
    $array->set(
	is_released => $aedb->get_is_released($acc),
    );
    $array->set(
	in_data_warehouse => $aedb->get_array_in_data_warehouse($acc),
    );

    # Skip metadata update for array designs having a release date
    # (this is a fairly arbitrary shortcut to reduce processing time).
    unless ( defined $has_metadata ) {
	update_heavy_array_queries( $array, $aedb );
    }

    # Save any changes.
    $array->update();

    return;
}

sub update_heavy_array_queries {

    my ( $array, $aedb ) = @_;

    my $acc = $array->accession();

    unless ( $acc ) {
	croak("Error: update_heavy_array_queries called with an invalid array design object (no accession).");
    }

    unless ( scalar ($array->organisms()) ) {
	my $species_list = $aedb->get_array_species($acc);
	foreach my $species ( @$species_list ) {
	    my $organism = ArrayExpress::AutoSubmission::DB::Organism->find_or_create({
		scientific_name => $species,
		is_deleted      => 0,
	    });
	    $array->add_to_organism_instances({
		array_design_id => $array,
		organism_id     => $organism,
	    });
	}
    }

    # Save any changes.
    $array->update();

    return;
}

sub max_job_dbids {

    my ( $aedb ) = @_;

    my %last_jobid;
    foreach my $instance ( @{ $aedb->get_instances() } ) {
	$last_jobid{$instance} =
	    ArrayExpress::AutoSubmission::DB::Event
		->sql_last_jobid('target_db')->select_val($instance);
    }

    return \%last_jobid;
}    

sub update_unfinished_events {

    my ( $aedb ) = @_;

    my $event_iterator = ArrayExpress::AutoSubmission::DB::Event->search(
	was_successful => undef,
	end_time       => undef,
	is_deleted     => 0,
    );

    while ( my $event = $event_iterator->next() ) {
	my ( $endtime, $success ) = $aedb->get_updated_event_data(
	    $event->jobregister_dbid(),
	    $event->target_db(),
	);

	if ( defined( $endtime ) || defined( $success ) ) {
	    printf STDOUT ("Updating event %s...\n", $event->jobregister_dbid());
	    $event->set(
		end_time       => $endtime,
		was_successful => $success,
	    );
	    $event->update();
	}
    }

    return;
}

# Separate autosubs DB queries from AE/AEDW queries. Transparently
# cache data (e.g. jobregister) retrieved from the AE databases.

# Optional autosubs clearing step; don't delete qt, factor or
# array_design instances, just the links to experiment.

# Iterate over experiments, array designs and query the cached AE data
# for results.

my ( $repopulating, $event_only, $metadata_only, $want_help );

GetOptions(
    "R|repopulate"    => \$repopulating,
    "E|event-only"    => \$event_only,
    "M|metadata-only" => \$metadata_only,
    "h|help"          => \$want_help,
);

if ( $want_help ) {

    print <<"USAGE";

    Usage: populate_tracking_info.pl

    Optional arguments:

	-R    Wipe the old tracking data and repopulate.
        -E    Only update Event data.
        -M    Only update Experiment and Array metadata.
	-h    Print this help text.

USAGE

    exit 255;
}

# This hash is inspected to figure out which operations need to be
# performed.
my %todo = (  # N.B. careful about how you add entries to this hash.
    events   => (not $metadata_only),
    metadata => (not $event_only),
);

# One single ArrayExpress::Tracking::QueryHandler query object used
# throughout. We want to use the largest jobregister_dbid as
# last_jobid here so that updates work correctly.
my $aedb = ArrayExpress::Tracking::QueryHandler->new();
unless ( $repopulating ) {
    my $last_jobid = max_job_dbids( $aedb );
    $aedb->set_last_jobid( $last_jobid );
}

# The first thing to do is to make sure we have a full list of
# every experiment and array design in the AE databases.
update_toplevel_objects( $aedb );

# FIXME we should consider wiping the release_date and is_released
# data every time we re-run the metadata updates.

# If we want a full repopulation we delete the old cached data here.
if ( $repopulating ) {

    print("WARNING: You have chosen to delete the following information, and repopulate from the AE databases:\n\n");
    print("    " . join("; ", grep { $todo{$_} } keys %todo) . "\n\nProceed (Y/N)? ");

    chomp( my $choice = lc <STDIN> );

    unless( $choice eq 'y' ) {
	print("User terminated script execution.\n");
	exit 255;
    }

    delete_cached_data( $aedb, \%todo );
}

# Update experiments here.
my $expt_iterator = ArrayExpress::AutoSubmission::DB::Experiment->search(
    is_deleted => 0,
);

EXPT:
while ( my $expt = $expt_iterator->next() ) {

    # Skip experiments without assigned accessions.
    next EXPT unless $expt->accession();

    printf STDOUT ("Updating experiment %s...\n", $expt->accession());

    update_events( $expt, $aedb )        if $todo{events};
    update_expt_metadata( $expt, $aedb ) if $todo{metadata};
}

# Update array designs here.
my $array_iterator = ArrayExpress::AutoSubmission::DB::ArrayDesign->search(
    is_deleted => 0,
);

ARRAY_DESIGN:
while ( my $array_design = $array_iterator->next() ) {

    # Skip array designs without assigned accessions.
    next ARRAY_DESIGN unless $array_design->accession();

    printf STDOUT ("Updating array design %s...\n", $array_design->accession());

    update_events( $array_design, $aedb )         if $todo{events};
    update_array_metadata( $array_design, $aedb ) if $todo{metadata};
}

# Finally, update any previously-unfinished events.
update_unfinished_events( $aedb ) if $todo{events};

