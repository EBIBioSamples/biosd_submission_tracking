#!/usr/bin/env perl
#
# Script to populate the tracking database with MD5 hashes of data
# BLOBs loaded into ArrayExpress (tt_biodatacube.netcdf) for the
# purposes of quality control. This script is designed to be run as a
# cron job, around once per day.
#
# $Id$

use strict;
use warnings;

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use Digest::MD5;
use Getopt::Long;

use ArrayExpress::AutoSubmission::DB::LoadedData;
use ArrayExpress::AutoSubmission::DB::DataFormat;
use ArrayExpress::AutoSubmission::DB::Experiment;
use ArrayExpress::Curator::Database qw(get_ae_dbh);
use ArrayExpress::Curator::Common qw(date_now);

########
# SUBS #
########

sub delete_unused_data {

    my ( $ae_dbh ) = @_;

    print qq{Scanning for recently deleted data objects...\n};

    my $records = ArrayExpress::AutoSubmission::DB::LoadedData->search(
	is_deleted => 0,
    );

    # FIXME modify this to confirm that there's a "valid" experiment
    # accession; i.e. not E-XXXX-n_bad or whatever. Will probably need
    # caching a big AE query.
    my $ae_sth = $ae_dbh->prepare(<<'QUERY');
select identifier
from tt_identifiable
where identifier=?
QUERY

    while ( my $data = $records->next() ) {
	$ae_sth->execute( $data->identifier() ) or die( $ae_sth->errstr() );
	my $results = $ae_sth->fetchall_arrayref();
	unless ( scalar @{ $results } ) {
	    printf( q{Deleting obsolete record "%s"...}, $data->identifier() );
	    $data->set('is_deleted' => 1);
	    $data->update();
	    print qq{ done.\n};
	}
    }

    $ae_sth->finish();

    return;
}

sub get_old_hashed_data {

    print( q{Caching experiment accessions and data identifiers...} );

    my $hashed_data = {};

    my $dbh = ArrayExpress::AutoSubmission::DB->db_Main();

    my $sth = $dbh->prepare(<<'QUERY');
select e.accession, d.identifier
from experiments e, loaded_data d, experiments_loaded_data ed
where e.id=ed.experiment_id
and d.id=ed.loaded_data_id
and d.is_deleted=0
QUERY

    $sth->execute() or die( $sth->errstr() );

    while ( my $row = $sth->fetchrow_hashref( 'NAME_lc' ) ) {
	$hashed_data->{ $row->{'accession'} }{ $row->{'identifier'} }++;
    }

    $sth->finish();

    print( qq{ done.\n} );

    return $hashed_data;
}

{

    my $cached_query;

sub needs_hashing {

    my ( $row ) = @_;

    # Quick look to see if the data has been already hashed.
    $cached_query ||= get_old_hashed_data();
    return if $cached_query->{ $row->{'accession'} }{ $row->{'identifier'} };

    # More detailed look to check linkage etc.
    my $experiment = ArrayExpress::AutoSubmission::DB::Experiment->find_or_create({
	accession  => $row->{'accession'},
	is_deleted => 0,
    });
    my %attached = map { $_->identifier() => 1 } $experiment->loaded_data();
    if ( $attached{ $row->{'identifier'} } ) {

	# Data file has been processed and is atteched.
	return;
    }

    my @data = ArrayExpress::AutoSubmission::DB::LoadedData->search(
	identifier => $row->{'identifier'},
	is_deleted => 0,
    );
    if ( scalar @data ) {
	foreach my $datum ( @data ) {    # Should be only one, but just in case...
	    print qq{Attaching hash "$row->{identifier}"}
		. qq{ to experiment "$row->{accession}"...\n};
	    $experiment->add_to_loaded_data_instances({
		loaded_data_id => $datum,
	    });
	}
	return;
    }

    return $experiment;
}

}

sub hash_row_data {

    my ( $row, $experiment, $ae_dbh ) = @_;

    print( qq{Hashing data for "$row->{identifier}"...} );

    my $md5         = Digest::MD5->new();

    my $lob_locator = $row->{'lob'};
    my $length      = $ae_dbh->ora_lob_length( $lob_locator );
    my $chunksize   = 65536;

    # Read in the LOB and add it to a Digest::MD5 object.
    for ( my $i = 1; $i <= $length; $i += $chunksize ) {
	my $chunk = $ae_dbh->ora_lob_read( $lob_locator, $i, $chunksize );
	$md5->add( $chunk );
    }

    # Create records in the SQLite DB for this data file.
    my $format = ArrayExpress::AutoSubmission::DB::DataFormat->find_or_create({
	name => $row->{'dataformat'},
    });
    my $datafile = ArrayExpress::AutoSubmission::DB::LoadedData->create({
	identifier     => $row->{'identifier'},
	data_format_id => $format,
	md5_hash       => $md5->hexdigest(),
	is_deleted     => 0,
	needs_metrics_calculation => 1,
	date_hashed    => date_now(),
    });
    $datafile->add_to_loaded_data_instances({
	experiment_id => $experiment,
    });

    print( qq{ done.\n} );

    return;
}

sub import_data_hashes {

    my ( $dataformat, $ae_dbh ) = @_;

    my $ae_sth = $ae_dbh->prepare(<<'QUERY', { ora_auto_lob => 0 });
select i.identifier as accession,
 di.identifier as identifier,
 bdc.dataformat as dataformat,
 bdc.netcdf as lob
from tt_identifiable i,
 tt_experiment e,
 tt_bioassaydata_t_experimen de,
 tt_bioassaydata d,
 tt_identifiable di,
 tt_biodatacube bdc,
 pl_label l
where i.id=e.id
and i.id=l.mainobj_id
and e.id=de.t_experiment_id
and de.bioassaydata_id=d.id
and d.id=di.id
and d.biodatavalues_id=bdc.id
and bdc.dataformat=?
and i.identifier!='E-TABM-185'
QUERY

    $ae_sth->execute( $dataformat ) or die( $ae_sth->errstr() );

    ROW:
    while ( my $row = $ae_sth->fetchrow_hashref( 'NAME_lc' ) ) {

	# Skip obviously bad accessions.
	next ROW unless ( $row->{'accession'} =~ m/\A E-[A-Z]{4}-\d+[a-zA-Z]* \z/xms );

	# Skip data files we've already processed.

	# First, check this experiment to see if the file has already
	# been processed and atteched.
	my $experiment = needs_hashing( $row );
	next ROW unless ( $experiment );

	hash_row_data( $row, $experiment, $ae_dbh );
    }

    $ae_sth->finish();

    return;
}

sub parse_args {

    my ( $dataformat, $updatemode );

    GetOptions(
	"f|format=s" => \$dataformat,
	"u|update"   => \$updatemode,
    );

    unless ( defined $dataformat || defined $updatemode ) {

	print <<"USAGE";
    Usage: $0 -f <data format>

           This hashes all new data of the specified format.

       or: $0 -u

           This hashes all new data of the formats already
           loaded into the tracking database. This will also
           delete data hashes from the tracking database where
           they have been deleted from ArrayExpress.

    Example: $0 -f CELv3

USAGE

	exit 255;
    }

    # Quick sanity check - some things aren't really supported yet.
    if ( $dataformat
	     && $dataformat =~ /\A \b (tab|whitespace) [ ]* (delimited)? \z/ixms ) {
	die("\n    I'm sorry Dave, I can't do that.\n\n  (Unsupported format: $dataformat)\n\n");
    }

    return ( $dataformat, $updatemode );
}

########
# MAIN #
########

# Autoflush STDOUT.
$| = 1;

my ( $dataformat, $updatemode ) = parse_args();

my $ae_dbh = get_ae_dbh();

# Run the hashing function.
if ( defined $dataformat ) {
    import_data_hashes( $dataformat, $ae_dbh );
}
elsif ( defined $updatemode ) {

    # Clean the table to remove data objects which no longer exist in AE.
    delete_unused_data( $ae_dbh );

    my $format = ArrayExpress::AutoSubmission::DB::DataFormat->retrieve_all();
    while ( defined( my $df = $format->next() ) ) {
	printf ( qq{Looking for new data in the "%s" format...\n}, $df->name() );
	import_data_hashes( $df->name(), $ae_dbh );
    }
}
