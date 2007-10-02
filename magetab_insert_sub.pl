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
use ArrayExpress::MAGETAB::IDF;

########
# MAIN #
########

my ($idf, $sdrf_arg, $magetab_doc, $login, $accession);

GetOptions(
    "i|idf=s"         => \$idf,
    "s|sdrf=s"        => \$sdrf_arg,
    "m|magetab=s"     => \$magetab_doc,
    "l|login=s"       => \$login,
    "A|accession=s"   => \$accession,
);

unless ( ($idf || $magetab_doc) && $login) {

    print STDERR (<<"USAGE");
Usage: $0 -i <IDF file> -l <login> <list of data file archives>

 Optional arguments:

    -A <accession number to assign to this submission>

    -s <SDRF file>

If the IDF is insufficiently well formatted for the parser to retrieve
the SDRF filename(s), then use -s to indicate the SDRF filename.

    -m <Combined IDF+SDRF document>

For combined MAGE-TAB documents such as those created by the template
generation system, use the -m option to insert.

USAGE

    exit 255;
}

my @sdrfs;
if ( defined($sdrf_arg) ) {
    push @sdrfs, $sdrf_arg;
}

# Figure out the SDRF name if not given
if ( $idf && ! scalar @sdrfs ) {
    my $parser = ArrayExpress::MAGETAB::IDF->new({
	idf             => $idf,
	expt_accession  => 'DUMMY',
	in_relaxed_mode => 1,
    });

    eval {
	my $sdrf_ref;
	(undef, undef, $sdrf_ref) = $parser->parse();
	@sdrfs = @{ $sdrf_ref };
    };
    if ($@) {
	die(  "Error parsing IDF file to retrieve SDRF filename. "
	    . "Please try using the -s option. Error was as follows:\n\n" . $@);
    }
    else {
	unless ( scalar @sdrfs ) {
	    die("Error: No SDRFs found in IDF. Please use the -s option to include SDRFs.\n");
	}
    }
}

my $startfile = ($idf || $magetab_doc);

# Quick sanity check on the file list.
foreach my $file ($startfile, @sdrfs, @ARGV) {
    die("Error: file not found: $file\n") unless ( defined($file) && -f $file && -r $file );
}

# Instantiate our Creator object.
my $creator = ArrayExpress::AutoSubmission::Creator->new({
    login           => $login,
    name            => $startfile,
    spreadsheet     => $startfile,
    data_files      => [ @sdrfs, @ARGV ],
    accession       => $accession,
    experiment_type => 'MAGE-TAB',
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
