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

##############################################################################
package AEDB::Event;

# Class used as a bridge between the AE database query objects and the
# tracking database.

use Class::Std;

my %event_type       : ATTR( :name<event_type>,       :default<undef> );
my %success          : ATTR( :name<success>,          :default<undef> );
my %source_db        : ATTR( :name<source_db>,        :default<undef> );
my %target_db        : ATTR( :name<target_db>,        :default<undef> );
my %starttime        : ATTR( :name<starttime>,        :default<undef> );
my %endtime          : ATTR( :name<endtime>,          :default<undef> );
my %machine          : ATTR( :name<machine>,          :default<undef> );
my %operator         : ATTR( :name<operator>,         :default<undef> );
my %log_file         : ATTR( :name<log_file>,         :default<undef> );
my %jobregister_dbid : ATTR( :name<jobregister_dbid>, :default<undef> );
my %comment          : ATTR( :name<comment>,          :default<undef> );

##############################################################################
package AEDB;

use Class::Std;
use Carp;
use Date::Manip qw(ParseDate UnixDate);

use ArrayExpress::Curator::Database qw(
    get_ae_dbh
    get_aedw_dbh
);

my %ae_dbhandle     : ATTR( :name<ae_dbhandle>,     :default<undef>     );
my %aedw_dbhandle   : ATTR( :name<aedw_dbhandle>,   :default<undef>     );
my %event_cache     : ATTR( :name<event_cache>,     :default<{}>        );
my %aerep_db        : ATTR( :name<aerep_db>,        :default<'AEPUB1'>  );
my %aedw_db         : ATTR( :name<aedw_db>,         :default<'AEDWDEV'> );
my %last_jobid      : ATTR( :name<last_jobid>,      :default<0>         );
my %cached_sth      : ATTR( :name<cached_sth>,      :default<{}>        );

sub BUILD {

    my ( $self, $id, $args ) = @_;

    $ae_dbhandle{ident $self} = get_ae_dbh()
	or croak("Error: Unable to connect to AE repository DB.");

    $aedw_dbhandle{ident $self} = get_aedw_dbh()
	or croak("Error: Unable to connect to AE warehouse DB.");

    # Long values are trimmed at 1000 chars.
    $ae_dbhandle{ident $self}->{LongReadLen} = 1000;
    $ae_dbhandle{ident $self}->{LongTruncOk} = 1;
    $aedw_dbhandle{ident $self}->{LongReadLen} = 1000;
    $aedw_dbhandle{ident $self}->{LongTruncOk} = 1;
}

sub START {

    my ( $self, $id, $args ) = @_;

    # Cache our jobregister events.
    $self->cache_aerep_events();
    $self->cache_aedw_events();

    # Create our cached statement handles.
    $self->cache_statement_handles();
}

sub cache_statement_handles : PRIVATE {

    my ( $self ) = @_;

    print STDOUT "Caching statement handles...\n";

    my $dbh = $self->get_ae_dbhandle();
    
    $cached_sth{ident $self}{expt_species} = $dbh->prepare(<<"QUERY");
select unique o.value
from tt_experiment e,
tt_biomaterials_experiments eb,
tt_poly_biomaterial pb,
tt_characteris_t_biomateri bso,
tt_ontologyentry o,
tt_identifiable i
where i.identifier = ?
and e.id = eb.experiments_id
and i.id = eb.experiments_id
and eb.biomaterials_id = pb.id
and pb.t_biosource_id is not null
and pb.t_biosource_id = bso.t_biomaterial_id
and bso.characteristics_id = o.id
and lower(o.category) = 'organism'
QUERY

    $cached_sth{ident $self}{array_species} = $dbh->prepare(<<"QUERY");
select unique oe.value
from tt_arraydesign ad,
tt_reportergro_t_arraydesi rg,
tt_designelementgroup de,
tt_ontologyentry oe,
tt_identifiable i
where i.identifier = ?
and ad.id = i.id
and rg.t_arraydesign_id = ad.id
and de.id = rg.reportergroups_id
and de.species_id = oe.id
and lower(oe.category) = 'organism'
QUERY

    $cached_sth{ident $self}{expt_arrays} = $dbh->prepare(<<"QUERY");
select unique iden.identifier
from tt_bioassays_t_experiment bt,
tt_poly_bioassay poly_b,
tt_physicalbioassay pba,
tt_bioassaycreation bc,
tt_array ar,
tt_arraydesign ard,
tt_identifiable iden,
tt_identifiable i
where i.identifier = ?
and i.id = bt.t_experiment_id
and poly_b.t_physicalbioassay_id = bt.bioassays_id
and pba.id = poly_b.t_physicalbioassay_id
and pba.bioassaycreation_id = bc.id
and bc.array_id = ar.id
and ar.arraydesign_id = ard.id
and ard.id = iden.id
QUERY

    $cached_sth{ident $self}{num_samples} = $dbh->prepare(<<"QUERY");
select count (unique pb.t_biosource_id) as samples
from tt_biomaterials_experiments be,
tt_biomaterial bm,
tt_poly_biomaterial pb,
tt_biosample bs,
tt_identifiable i
where i.identifier = ?
and be.experiments_id = i.id
and be.biomaterials_id = bm.id
and bm.id = pb.t_biosource_id
QUERY

    $cached_sth{ident $self}{num_hybridizations} = $dbh->prepare(<<"QUERY");
select count( cp.t_hybridization_id ) as hybs
from tt_experiment e,
tt_bioassays_t_experiment eb,
tt_poly_bioassay bp,
tt_physicalbioassay pba,
tt_poly_bioassaycreation cp,
tt_identifiable i
where i.identifier = ?
and e.id = i.id
and e.id = eb.t_experiment_id
and eb.bioassays_id = bp.t_physicalbioassay_id
and bp.t_physicalbioassay_id = pba.id
and pba.bioassaycreation_id = cp.id
and cp.t_hybridization_id is not null
QUERY

    $cached_sth{ident $self}{expt_factors} = $dbh->prepare(<<"QUERY");
select oe.value as value
from tt_experimentdesign ed,
tt_experimentalfactor ef,
tt_ontologyentry oe,
tt_identifiable i
where i.identifier = ?
and ed.t_experiment_id = i.id
and ef.t_experimentdesign_id = ed.id
and oe.id = ef.category_id
QUERY

    $cached_sth{ident $self}{expt_qts} = $dbh->prepare(<<"QUERY");
select unique iden.name as name
from tt_bioassaydata_t_experimen bte,
tt_bioassaydata ba,
tt_quantitationtypedimension qtd,
tt_quantitatio_t_quantitat qtq,
tt_quantitationtype qt,
tt_identifiable iden,
tt_identifiable i
where i.identifier = ?
and bte.t_experiment_id = i.id
and ba.id = bte.bioassaydata_id
and qtd.id = ba.quantitationtypedimension_id
and qtq.t_quantitationtypedimension_id = ba.quantitationtypedimension_id
and qt.id = qtq.quantitationtypes_id
and iden.id = qt.id
QUERY

    $cached_sth{ident $self}{is_released} = $dbh->prepare(<<"QUERY");
select usr.name
from pl_visibility vi,
pl_label la,
tt_identifiable i,
pl_user usr
where i.identifier = ?
and i.identifier = la.mainobj_name
and la.id = vi.label_id
and vi.user_id = usr.id
and usr.name = 'guest'
QUERY

    $cached_sth{ident $self}{release_date} = $dbh->prepare(<<"QUERY");
select nvt.value
from tt_namevaluetype nvt,
tt_identifiable i
where i.identifier = ?
and nvt.t_extendable_id = i.id
and nvt.name ='ArrayExpressReleaseDate'
QUERY

    $cached_sth{ident $self}{ae_miame_score} = $dbh->prepare(<<"QUERY");
select nvt.value
from tt_namevaluetype nvt,
tt_identifiable i
where i.identifier = ?
and nvt.t_extendable_id = i.id
and nvt.name ='AEMIAMESCORE'
QUERY

    $cached_sth{ident $self}{curated_name} = $dbh->prepare(<<"QUERY");
select nvt.value
from tt_namevaluetype nvt,
tt_identifiable i
where i.identifier = ?
and nvt.t_extendable_id = i.id
and nvt.name ='AEExperimentDisplayName'
QUERY

    $cached_sth{ident $self}{submitter_description} = $dbh->prepare(<<"QUERY");
select d.text
from tt_description d,
tt_identifiable i
where i.identifier = ?
and d.t_describable_id = i.id
and d.text not like '(Generated description)%'
and length(d.text) > 0
QUERY
    
}

sub get_experiments {

    my ( $self ) = @_;

    # FIXME we might want to extend this to include the AEDW.
    my $dbh = $self->get_ae_dbhandle();

    my $sth = $dbh->prepare(<<"QUERY");
select i.identifier
from tt_identifiable i,
tt_experiment e
where e.id = i.id
QUERY

    $sth->execute() or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return [ map { $_->[0] } @{ $results } ];
}

sub get_array_designs {

    # FIXME we might want to extend this to include the AEDW.
    my ( $self ) = @_;

    my $dbh = $self->get_ae_dbhandle();

    my $sth = $dbh->prepare(<<"QUERY");
select i.identifier
from tt_identifiable i,
tt_physicalarraydesign a
where a.id = i.id
QUERY

    $sth->execute() or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return [ map { $_->[0] } @{ $results } ];
}

sub get_expt_species {

    my ( $self, $accession ) = @_;

    # Query returns Organism OE values.
    my $sth = $self->get_cached_sth()->{expt_species}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );

    my $results = $sth->fetchall_arrayref();

    return [ map { $_->[0] } @{ $results } ];
}

sub get_expt_arrays {

    my ( $self, $accession ) = @_;

    # Query returns array accessions.
    my $sth = $self->get_cached_sth()->{expt_arrays}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return [ map { $_->[0] } @{ $results } ];
}

sub get_expt_factors {

    my ( $self, $accession ) = @_;

    # Query returns ExperimentalFactorCategory OE values.
    my $sth = $self->get_cached_sth()->{expt_factors}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return [ map { $_->[0] } @{ $results } ];
}

sub get_expt_qts {

    my ( $self, $accession ) = @_;

    # Query returns QT names.
    my $sth = $self->get_cached_sth()->{expt_qts}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return [ map { $_->[0] } @{ $results } ];
}

sub get_submitter_description {

    my ( $self, $accession ) = @_;

    # Query returns Description texts.
    my $sth = $self->get_cached_sth()->{submitter_description}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return $results->[0][0];
}

sub get_curated_name {

    my ( $self, $accession ) = @_;

    # Query returns the curated name (AEExperimentDisplayName NVT).
    my $sth = $self->get_cached_sth()->{curated_name}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return $results->[0][0];
}

sub get_num_samples {

    my ( $self, $accession ) = @_;

    # Query returns count of samples.
    my $sth = $self->get_cached_sth()->{num_samples}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return $results->[0][0];
}

sub get_num_hybridizations {

    my ( $self, $accession ) = @_;

    # Query returns count of samples.
    my $sth = $self->get_cached_sth()->{num_hybridizations}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return $results->[0][0];
}

sub get_release_date {

    my ( $self, $accession ) = @_;

    # Query returns the release date (ArrayExpressReleaseDate NVT).
    my $sth = $self->get_cached_sth()->{release_date}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return $results->[0][0];
}

sub get_is_released {

    my ( $self, $accession ) = @_;

    # If query returns anything, object is public.
    my $sth = $self->get_cached_sth()->{is_released}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return scalar @{ $results } ? 1 : 0;
}

sub get_ae_miame_score {

    my ( $self, $accession ) = @_;

    # Query returns the AE-computed MIAME score (AEMIAMESCORE NVT).
    my $sth = $self->get_cached_sth()->{ae_miame_score}
	or die("Error: Undefined statement handle.");

    $sth->execute( $accession ) or die( $sth->errstr() );
    
    my $results = $sth->fetchall_arrayref();

    return $results->[0][0];
}

sub get_ae_data_warehouse_score {

    my ( $self, $accession ) = @_;

    confess("Not implemented yet"); # FIXME once this has been implemented in AE.
}

sub get_events {

    my ( $self, $accession ) = @_;

    return $self->get_event_cache()->{ $accession } || [];
}

sub cache_aerep_events : PRIVATE {

    my ( $self ) = @_;

    print STDOUT "Caching AE repository events...\n";

    my $dbh = $self->get_ae_dbhandle();

    $self->cache_events( $dbh, $self->get_aerep_db() );
}

sub cache_aedw_events : PRIVATE {

    my ( $self ) = @_;

    print STDOUT "Caching AE warehouse events...\n";

    my $dbh = $self->get_aedw_dbhandle();

    $self->cache_events( $dbh, $self->get_aedw_db() );
}

sub cache_events : PRIVATE {

    my ( $self, $dbh, $instance ) = @_;

    # Note that currently the AEDW and AEREP jobregister schemas are
    # identical, so we use this code for both. We may need to change
    # this if these schemas change.

    # Populate the event_cache with AEDB::Event objects here.
    my $sth = $dbh->prepare(<<"QUERY");
select distinct ID, USERNAME, DIRNAME, JOBTYPE, STARTTIME, ENDTIME, PHASE
from jobregister
where id > ?
and endtime is not null
QUERY

    $sth->execute( $self->get_last_jobid() ) or die( $sth->errstr() );

    my $event = $self->get_event_cache();

    JOB:
    while ( my $hashref = $sth->fetchrow_hashref() ) {

	# FIXME this regexp will miss some accessions (e.g. E-TABM-145b).
	my ( $accession )
	    = ( $hashref->{'DIRNAME'} =~ m/\/([AE]-[A-Z]{4}-[0-9]+)/ );
	next JOB unless $accession;

	my $obj = $self->make_event_object( $hashref, $instance );
	push( @{ $event->{$accession} }, $obj );
    }

    $self->set_event_cache($event);
}

sub make_event_object : PRIVATE {

    my ( $self, $hashref, $instance ) = @_;

    # N.B. currently the AEREP and AEDW jobregister tables have
    # identical columns; we may need to make database-specific
    # versions of this method if that ever changes.

    # Here we map the AEREP column names to our events. Attributes not
    # set: source_db, machine, log_file, comment. Note that we need to
    # parse the returned date format here.
    foreach my $key qw(STARTTIME ENDTIME) {
	my $date = ParseDate($hashref->{$key});
	$hashref->{$key} = UnixDate($date, "%Y-%m-%d %T");
    }
    my $obj = AEDB::Event->new({
	event_type       => $hashref->{'JOBTYPE'},
	success          => ( ( $hashref->{'PHASE'} eq 'finished' ) ? 1 : 0 ),
	target_db        => $instance,
	starttime        => $hashref->{'STARTTIME'},
	endtime          => $hashref->{'ENDTIME'},
	operator         => $hashref->{'USERNAME'},
	jobregister_dbid => $hashref->{'ID'},
    });

    return $obj;
}

##############################################################################
package main;

use Getopt::Long;
use Carp;
use List::Util qw(first);

use ArrayExpress::AutoSubmission::DB;

sub update_toplevel_objects {

    my ( $aedb ) = @_;

    print STDOUT "Inserting new experiment records...\n";
    my $ae_experiments = $aedb->get_experiments();
    my @prev_expts = ArrayExpress::AutoSubmission::DB::Experiment->search(
	is_deleted => 0,
    );
    my @prev_expt_accns = map { $_->accession() } @prev_expts;
    foreach my $accession ( @$ae_experiments ) {
	unless ( first { $_ eq $accession } @prev_expt_accns ) {
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
    foreach my $accession ( @$ae_arrays ) {
	unless ( first { $_ eq $accession } @prev_array_accns ) {
	    ArrayExpress::AutoSubmission::DB::ArrayDesign->find_or_create({
		accession  => $accession,
		is_deleted => 0,
	    });
	}
    }
}

sub delete_cached_data {

    my ( $aedb ) = @_;

    # The aedb query object contains information on what *can* be
    # repopulated - and therefore deleted here.

    # Delete all events associated with the database instances of interest.
    foreach my $instance ( $aedb->get_aerep_db(), $aedb->get_aedw_db() ) {
	ArrayExpress::AutoSubmission::DB::Event->search(
	    target_db => $instance,
	)->delete_all();
    }

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

	$expt->set(
	    submitter_description   => undef,
	    curated_name            => undef,
	    num_samples             => undef,
	    num_hybridizations      => undef,
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

	$array->set(
	    release_date            => undef,
	    is_released             => undef,
	);

	$array->organism_instances()->delete_all();
	
	$array->update();
    }
}

sub update_events {

    my ( $object, $aedb ) = @_;

    # $object can be an experiment or array_design.

    unless ( $object->accession() ) {
	croak("Error: update_events called with an invalid experiment object (no accession).");
    }

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
}

sub update_expt_metadata {

    my ( $expt, $aedb ) = @_;

    # FIXME not implemented: ae_data_warehouse_score.

    my $acc = $expt->accession();

    unless ( $acc ) {
	croak("Error: update_expt_metadata called with an invalid experiment object (no accession).");
    }

    unless ( defined ($expt->submitter_description()) ) {
	$expt->set(
	    submitter_description => $aedb->get_submitter_description($acc),
	);
    }
    unless ( defined ($expt->curated_name()) ) {
	$expt->set(
	    curated_name => $aedb->get_curated_name($acc),
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
    unless ( defined ($expt->release_date()) ) {
	$expt->set(
	    release_date => $aedb->get_release_date($acc),
	);
    }
    unless ( defined ($expt->is_released()) ) {
	$expt->set(
	    is_released => $aedb->get_is_released($acc),
	);
    }
    unless ( defined ($expt->ae_miame_score()) ) {
	$expt->set(
	    ae_miame_score => $aedb->get_ae_miame_score($acc),
	);
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
}

sub update_array_metadata {

    my ( $array, $aedb ) = @_;

    # FIXME not implemented: annotation_source, annotation_version, biomart_table_name.

    my $acc = $array->accession();

    unless ( $acc ) {
	croak("Error: update_array_metadata called with an invalid array design object (no accession).");
    }

    unless ( defined ($array->release_date()) ) {
	$array->set(
	    release_date => $aedb->get_release_date($acc),
	);
    }
    unless ( defined ($array->is_released()) ) {
	$array->set(
	    is_released => $aedb->get_is_released($acc),
	);
    }
    unless ( scalar ($array->organisms()) ) {
	my $species_list = $aedb->get_array_species($acc);
	foreach my $species ( @$species_list ) {
	    my $organism = ArrayExpress::AutoSubmission::DB::Organism->find_or_create({
		scientific_name => $species,
		is_deleted      => 0,
	    });
	    $array->add_to_organism_instances({
		experiment_id => $array,
		organism_id   => $organism,
	    });
	}
    }

    # Save any changes.
    $array->update();
}

sub max_job_dbid {

    return ArrayExpress::AutoSubmission::DB::Event->maximum_value_of('jobregister_dbid') || 0;
}    

# Separate autosubs DB queries from AE/AEDW queries. Transparently
# cache data (e.g. jobregister) retrieved from the AE databases.

# Optional autosubs clearing step; don't delete qt, factor or
# array_design instances, just the links to experiment.

# Iterate over experiments, array designs and query the cached AE data
# for results.

my ( $repopulating, $want_help );

GetOptions(
    "R|repopulate" => \$repopulating,
    "h|help"       => \$want_help,
);

if ( $want_help ) {

    print <<"USAGE";

    Usage: populate_tracking_info.pl

    Optional arguments:

	-R    Wipe the old tracking data and repopulate.
	-h    Print this help text.

USAGE

    exit 255;
}

# One single AEDB query object used throughout. This may turn out to
# be a bit memory-hungry; we'll see when we come to test it. We
# want to use the largest jobregister_dbid as last_jobid here so that
# updates work correctly.
my $last_jobid = 0;
unless ( $repopulating ) {
    $last_jobid = max_job_dbid();
}
my $aedb = AEDB->new({
    last_jobid => $last_jobid,
});

# The first thing to do is to make sure we have a full list of
# every experiment and array design in the AE databases.
update_toplevel_objects( $aedb );

# If we want a full repopulation we delete the old cached data here.
if ( $repopulating ) {

    print("WARNING: You have chosen to delete the event tracking data and "
	. "experiment/array design metadata, and repopulate the database. Proceed (Y/N)? ");

    chomp( my $choice = <STDIN> );

    unless( lc($choice) eq 'y' ) {
	print("User terminated script execution.\n");
	exit 255;
    }

    delete_cached_data( $aedb );
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

    update_expt_metadata( $expt, $aedb );
    update_events( $expt, $aedb );
}

# Update array designs here.
my $array_iterator = ArrayExpress::AutoSubmission::DB::ArrayDesign->search(
    is_deleted => 0,
);

ARRAY_DESIGN:
while ( my $array_design = $array_iterator->next() ) {

    # Skip experiments without assigned accessions.
    next ARRAY_DESIGN unless $array_design->accession();

    printf STDOUT ("Updating array design %s...", $array_design->accession());

    update_array_metadata( $array_design, $aedb );
    update_events( $array_design, $aedb );
}
