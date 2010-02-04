#!/usr/bin/perl
#
# Script to add a new submission to the autosubmissions
# system (used e.g. for FTP uploaded submissions).
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use Getopt::Long;
use ArrayExpress::AutoSubmission::DB;
use ArrayExpress::AutoSubmission::DB::Pipeline;
use ArrayExpress::AutoSubmission::Creator;
use ArrayExpress::Curator::Config qw($CONFIG);
use ArrayExpress::Curator::Common qw(date_now);


########
# MAIN #
########

my ($spreadsheet, $type, $login, $accession);

GetOptions(
    "s|spreadsheet=s" => \$spreadsheet,
    "t|type=s"        => \$type,
    "l|login=s"       => \$login,
    "A|accession=s"   => \$accession,
);

unless ( $spreadsheet && $type && $login) {

    print STDERR (<<"USAGE");
Usage: $0 -t <type> -s <spreadsheet> -l <login> <list of data file archives>

 Optional arguments:

    -A <accession number to assign to this submission>

USAGE

    exit 255;
}

# Check the experiment type is recognized
my ($pipeline) = ArrayExpress::AutoSubmission::DB::Pipeline->search(submission_type=>$type);
unless ($pipeline){
	die "Submission type $type not recognized\n";
}

# Quick sanity check on the file list.
foreach my $file ($spreadsheet, @ARGV) {
    die("Error: file not found: $file\n") unless ( defined($file) && -f $file && -r $file );
}

# Instantiate our Creator object.
my $creator = ArrayExpress::AutoSubmission::Creator->new({
    login           => $login,
    name            => $spreadsheet,
    spreadsheet     => $spreadsheet,
    data_files      => [ @ARGV ],
    accession       => $accession,
    experiment_type => $type,
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
    status          => $CONFIG->get_STATUS_PENDING(),
    in_curation     => 1,
    num_submissions => ( $expt->num_submissions() + 1 ),
);
$expt->update();