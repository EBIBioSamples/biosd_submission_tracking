#!/usr/bin/env perl
#
# Script to automate MAGE-ML export for MIAMExpress experiments which
# have passed automated checking.
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use ArrayExpress::AutoSubmission::Daemon::MXExporter;
use ArrayExpress::Curator::Config qw($CONFIG);

# Create the daemon object and start exporting.
my $daemon = ArrayExpress::AutoSubmission::Daemon::MXExporter->new({
    polling_interval  => 5,
    experiment_type   => 'MIAMExpress',
    accession_prefix  => 'E-MEXP-',
    mx_export_command => $CONFIG->get_MX_MAGEML_EXPORT_COMMAND(),
    autosubs_admin    => $CONFIG->get_MX_AUTOSUBS_ADMIN(),
});

$daemon->run();
