#!/usr/bin/env perl
#
# Script to automate expt_check.pl running for newly-submitted MX experiments
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use ArrayExpress::AutoSubmission::Daemon::MXChecker;
use ArrayExpress::Curator::Config qw($CONFIG);

# Create the daemon object and start checking.
my $daemon = ArrayExpress::AutoSubmission::Daemon::MXChecker->new({
    polling_interval  => 5,
    checker_threshold => ($CONFIG->get_ERROR_INNOCENT()
 		        | $CONFIG->get_ERROR_MIAME()),
    experiment_type   => 'MIAMExpress',
    accession_prefix  => 'E-MEXP-',
    autosubs_admin    => $CONFIG->get_MX_AUTOSUBS_ADMIN(),
    mx_dsn            => $CONFIG->get_MX_DSN(),
    mx_username       => $CONFIG->get_MX_USERNAME(),
    mx_password       => $CONFIG->get_MX_PASSWORD(),
    mx_dbparams       => $CONFIG->get_MX_DBPARAMS(),
});

$daemon->run();
