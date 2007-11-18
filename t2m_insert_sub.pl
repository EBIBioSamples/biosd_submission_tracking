#!/usr/bin/env perl
#
# Script to add a new tab2mage submission to the autosubmissions
# system (used e.g. for FTP uploaded submissions).
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use Getopt::Long;
use ArrayExpress::AutoSubmission::DB;
use ArrayExpress::AutoSubmission::Creator;
use ArrayExpress::Curator::Config qw($CONFIG);
use ArrayExpress::Curator::Common qw(date_now);

########
# MAIN #
########

my ($spreadsheet, $login, $accession);

GetOptions(
    "e|spreadsheet=s" => \$spreadsheet,
    "l|login=s"       => \$login,
    "A|accession=s"   => \$accession,
);

unless ($spreadsheet && $login) {

    print STDERR (<<"USAGE");
Usage: $0 -e <spreadsheet> -l <login> <list of data file archives>

 Optional argument:

    -A <accession number to assign to this submission>

USAGE

    exit 255;
}

# Quick sanity check on the file list.
foreach my $file ($spreadsheet, @ARGV) {
    die("Error: file not found: $file\n") unless ( -f $file && -r $file );
}

# Instantiate our Creator object.
my $creator = ArrayExpress::AutoSubmission::Creator->new({
    login           => $login,
    name            => $spreadsheet,
    spreadsheet     => $spreadsheet,
    data_files      => \@ARGV,
    accession       => $accession,
    experiment_type => 'Tab2MAGE',
    comment         => 'Submission inserted manually',
    clobber         => 0,
});

# Create the experiment and insert the spreadsheet.
my $expt = $creator->get_experiment();

# Copy the files to the submissions directory.
print STDERR ("Copying files...\n");
$creator->insert_spreadsheet();
$creator->insert_data_files();

# Now we're all set, release the hounds.
$expt->set(
    status      => $CONFIG->get_STATUS_PENDING(),
    in_curation => 1,
);
$expt->update();
