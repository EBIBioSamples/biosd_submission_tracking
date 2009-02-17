#!/usr/bin/env perl
#
# Script to automate MAGE-ML export for BII MAGE-TAB experiments which
# have passed automated checking.
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use ArrayExpress::AutoSubmission::Daemon::MAGETABExporter;
use ArrayExpress::Curator::Config qw($CONFIG);

# Create the daemon object and start exporting.
my $daemon = ArrayExpress::AutoSubmission::Daemon::MAGETABExporter->new({
    polling_interval  => 5,
    experiment_type   => 'BII',
    autosubs_admin    => $CONFIG->get_AUTOSUBS_ADMIN(),
    pipeline_subdir   => 'BIID',
    accession_prefix  => 'E-BIID-',
});

$daemon->run();