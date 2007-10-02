#!/usr/bin/env perl
#
# Script to automate expt_check.pl running for newly-submitted tab2mage experiments
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use ArrayExpress::AutoSubmission::Daemon::Checker;
use ArrayExpress::Curator::Config qw($CONFIG);

# Create the daemon object and start checking.
my $daemon = ArrayExpress::AutoSubmission::Daemon::T2MChecker->new({
    polling_interval  => 5,
    checker_threshold => ($CONFIG->get_ERROR_INNOCENT()
 		        | $CONFIG->get_ERROR_MIAME()),
    experiment_type   => 'Tab2MAGE',
    accession_prefix  => 'E-TABM-',
    autosubs_admin    => $CONFIG->get_AUTOSUBS_ADMIN(),
});

$daemon->run();
