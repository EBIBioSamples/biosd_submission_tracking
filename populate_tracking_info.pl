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

use ArrayExpress::Curator::Database qw(
    get_ae_dbh
    get_aedw_dbh
);

my %ae_dbh          : ATTR( :name<ae_dbh>,          :default<undef> );
my %aedw_dbh        : ATTR( :name<aedw_dbh>,        :default<undef> );
my %event_cache     : ATTR( :name<event_cache>,     :default<{}>    );
my %aerep_db        : ATTR( :name<aerep_db>,        :default<'AEPUB1'>  );
my %aedw_db         : ATTR( :name<aedw_db>,         :default<'AEDWDEV'> );
my %last_jobid      : ATTR( :name<last_jobid>,      :default<0>         );

sub BUILD {

    my ( $self, $id, $args ) = @_;

    $ae_dbh{ident $self} = get_ae_dbh()
	or croak("Error: Unable to connect to AE repository DB.");

    $aedw_dbh{ident $self} = get_aedw_dbh()
	or croak("Error: Unable to connect to AE warehouse DB.");
}

sub START {

    my ( $self, $id, $args ) = @_;

    # Cache our jobregister events.
    $self->cache_aerep_events();
    $self->cache_aedw_events();
}

sub get_events {

    my ( $self, $accession ) = @_;

    return $self->get_event_cache()->{ $accession } || [];
}

sub cache_aerep_events : PRIVATE {

    my ( $self ) = @_;

    my $dbh = $self->get_ae_dbh();

    $self->cache_events( $dbh );
}

sub cache_aedw_events : PRIVATE {

    my ( $self ) = @_;

    my $dbh = $self->get_aedw_dbh();

    $self->cache_events( $dbh );
}

sub cache_events : PRIVATE {

    my ( $self, $dbh ) = @_;

    # Note that currently the AEDW and AEREP jobregister schemas are
    # identical, so we use this code for both. We may need to change
    # this if these schemas change.
    
    # Populate the event_cache with AEDB::Event objects here.
    my $sth = $self->get_ae_dbh()->prepare(<<"QUERY");
select ID, USERNAME, DIRNAME, JOBTYPE, STARTTIME, ENDTIME, PHASE
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

	my $obj = $self->make_event_object( $hashref );
	push( @{ $event->{$accession} }, $obj );
    }

    $self->set_event_cache($event);
}

sub make_event_object : PRIVATE {

    my ( $self, $hashref ) = @_;

    # N.B. currently the AEREP and AEDW jobregister tables have
    # identical columns; we may need to make database-specific
    # versions of this method if that ever changes.

    # Here we map the AEREP column names to our events. Attributes not
    # set: source_db, machine, log_file, comment.
    my $obj = AEDB::Event->new({
	event_type       => $hashref->{'JOBTYPE'},
	success          => ( ( $hashref->{'PHASE'} eq 'finished' ) ? 1 : 0 ),
	target_db        => $self->get_aerep_db(),
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

use ArrayExpress::AutoSubmission::DB;

sub delete_cached_data {

    my ( $aedb ) = @_;

    # The aedb query object contains information on what *can* be
    # repopulated - and therefore deleted here.

    die"FIXME not implemented.";

}

sub update_events {

    my ( $object, $aedb ) = @_;

    # $object can be an experiment or array_design.

    unless ( $object->accession() ) {
	croak("Error: update_events called with an invalid experiment object (no accession).");
    }

    my $events = $aedb->get_event_data( $object->accession() );

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

    die"FIXME not implemented.";

}

sub update_array_metadata {

    die"FIXME not implemented.";

}

sub max_jobid {

    return ArrayExpress::AutoSubmission::DB::Event->maximum_value_of('jobregister_dbid');

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
# be a bit memory-hungry; we'll see when we come to test it. FIXME we
# want to use the largest jobregister_dbid as last_jobid here so that
# updates work correctly.
my $last_jobid = 0;
unless ( $repopulating ) {
    $last_jobid = max_job_dbid();
}
my $aedb = AEDB->new({
    last_jobid => $last_jobid,
});

# If we want a full repopulation we delete the old cached data here.
if ( $repopulating ) {

    print("WARNING: You have chosen to delete the event tracking data and "
	. "experiment/array design metadata and repopulate the database. Proceed (Y/N)? ");

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

    update_array_metadata( $array_design, $aedb );
    update_events( $array_design, $aedb );
}
