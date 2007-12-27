#!/usr/bin/env perl

# Script used to migrate 1.8 series DBD::CSV accession cache to 1.9
# series DBD::SQLite autosubmissions database. Note that the files in
# question must have Unix, not DOS linebreaks.

# Tim Rayner 2006 ArrayExpress Team, EBI
# $Id$

use strict;
use warnings;

##############################################
package AccessionCacheDB;
use base 'Class::DBI';

unless (@ARGV) {
    warn <<USAGE;
    Usage: $0 <DBD::CSV database directory> [ Tab2MAGE experiment web page (optional) ]

USAGE
    exit 255;
}

my $csvdir = shift @ARGV;
__PACKAGE__->connection(
    "dbi:CSV:f_dir=$csvdir",
    undef,
    undef,
    {csv_sep_char => "\t",
     csv_eol      => "\n",
     RaiseError   => 1,}
) or die();

##############################################
package AccessionCacheDB::Experiment;
use base 'AccessionCacheDB';
__PACKAGE__->table('mx_experiment');
__PACKAGE__->columns(
    All => qw(
	      subid
	      accession
	      name
	      user
	      checker_score
	      software
	      status
	      date_last_processed
	      comment
	      curator
	      data_warehouse_ready
	  )
);

##############################################
package AccessionCacheDB::Array;
use base 'AccessionCacheDB';
__PACKAGE__->table('mx_array');
__PACKAGE__->columns(
    All => qw(
	      subid
	      accession
	      name
	      user
	      status
	      date_last_processed
	      comment
	      data_warehouse_ready
	  )
);

##############################################
package AccessionCacheDB::Protocol;
use base 'AccessionCacheDB';
__PACKAGE__->table('t2m_protocol');
__PACKAGE__->columns(
    All => qw(
	      accession
	      user_accession
	      expt_accession
	      name
	  )
);

##############################################
package main;
require ArrayExpress::AutoSubmission::DB::Experiment;
require ArrayExpress::AutoSubmission::DB::ArrayDesign;
require ArrayExpress::AutoSubmission::DB::Protocol;
use ArrayExpress::Curator::Common qw(date_now);

my $date = date_now();

print STDERR ("Loading MIAMExpress experiments...\n");
foreach my $expt ( AccessionCacheDB::Experiment->retrieve_all() ) {
    ArrayExpress::AutoSubmission::DB::Experiment->insert({
	experiment_type => 'MIAMExpress',
        accession       => $expt->accession,
        name            => $expt->name,
        checker_score   => $expt->checker_score,
        software        => $expt->software,
        status          => $expt->status,
        data_warehouse_ready => $expt->data_warehouse_ready,
        date_last_processed  => $expt->date_last_processed,
        curator              => $expt->curator,
        comment              => $expt->comment,
        miamexpress_login    => $expt->user,
        miamexpress_subid    => $expt->subid,
	is_deleted           => 0,
    });
    print STDERR q{.};
}
print STDERR ("\n");

print STDERR ("Loading MIAMExpress arrays...\n");
foreach my $array ( AccessionCacheDB::Array->retrieve_all() ) {
    ArrayExpress::AutoSubmission::DB::ArrayDesign->insert({
        miamexpress_subid     => $array->subid,
        accession             => $array->accession,
        name                  => $array->name,
        miamexpress_login     => $array->user,
        status                => $array->status,
        data_warehouse_ready  => $array->data_warehouse_ready,
        date_last_processed   => $array->date_last_processed,
        comment               => $array->comment,
	is_deleted            => 0,
    });
    print STDERR q{.};
}
print STDERR ("\n");

print STDERR ("Loading Tab2MAGE protocols...\n");
foreach my $protocol ( AccessionCacheDB::Protocol->retrieve_all() ) {
    ArrayExpress::AutoSubmission::DB::Protocol->insert({
        accession           => $protocol->accession,
        user_accession      => $protocol->user_accession,
        expt_accession      => $protocol->expt_accession,
        name                => $protocol->name,
        date_last_processed => $date,
	comment             => 'from old system',
        is_deleted          => 0,	
    });
    print STDERR q{.};
}
print STDERR ("\n");

# If possible, parse an optional web page with tab2mage experiment info.
if ( my $t2m_webpage = shift @ARGV ) {

    print STDERR ("Loading Tab2MAGE experiments...\n");

    require LWP::UserAgent;
    require HTML::TableExtract;

    my $ua = LWP::UserAgent->new();

    my $response = $ua->get( $t2m_webpage );

    unless ( $response->is_success ) {
	croak(    "Error retrieving tab2mage experiments: "
		      . $response->status_line );
    }

    my $te = new HTML::TableExtract(
	headers => [
	    'Accession',
	    'Person',
	    'ExperimentDesignType',
	    'Experiment Name'
	]
    );
    $te->parse( $response->content );

    # Go for the first and only table.
    foreach my $row ($te->rows) {
	if ( $row->[0] =~ /E-TABM-\d+/ ) {
	    ArrayExpress::AutoSubmission::DB::Experiment->insert({
		experiment_type => 'Tab2MAGE',
		accession       => $row->[0],
		name            => $row->[3],
		status          => 'Complete',
		date_last_processed  => $date,
		comment         => "submitter: $row->[1]; design: $row->[2]",
		is_deleted      => 0,
	    });
	    print STDERR q{.};
	}
    }
}
print STDERR ("\n");
