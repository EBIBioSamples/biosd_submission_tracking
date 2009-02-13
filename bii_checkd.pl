#!/usr/bin/env perl
#
# Script to automate expt_check.pl running for newly-submitted BII MAGE-TAB experiments
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use ArrayExpress::AutoSubmission::Daemon::MAGETABChecker;
use ArrayExpress::Curator::Config qw($CONFIG);

# Create the daemon object and start checking.
my $daemon = ArrayExpress::AutoSubmission::Daemon::MAGETABChecker->new({
    polling_interval  => 5,
    checker_threshold => ($CONFIG->get_ERROR_INNOCENT()
 		        | $CONFIG->get_ERROR_MIAME()),
    experiment_type   => 'BII',
    accession_prefix  => 'E-BIID-',
    autosubs_admin    => $CONFIG->get_AUTOSUBS_ADMIN(),
});

$daemon->run();