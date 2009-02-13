#!/usr/bin/env perl
#
# Script to add a new BII MAGE-TAB submission to the autosubmissions
# system.
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

my ($idf, $sdrf_arg, $magetab_doc, $accession, $clobber);

GetOptions(
    "i|idf=s"         => \$idf,
    "s|sdrf=s"        => \$sdrf_arg,
    "m|magetab=s"     => \$magetab_doc,
    "A|accession=s"   => \$accession,
    "c|clobber"       => \$clobber,
);

unless ( ($idf || $magetab_doc) ) {

    print STDERR (<<"USAGE");
Usage: $0 -i <IDF file> <list of data file archives>

 Optional arguments:

    -s <SDRF file>

If the IDF is insufficiently well formatted for the parser to retrieve
the SDRF filename(s), then use -s to indicate the SDRF filename.

    -m <Combined IDF+SDRF document>

For combined MAGE-TAB documents such as those created by the template
generation system, use the -m option to insert.

   -A <ArrayExpress accession>

For resubmitting an experiment which already has an ArrayExpress accession.

   -c <clobber>
   
Use clobber to overwrite any existing files for the experiment without prompting
   
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


# If accession is provided this is an update. Check the accession is already in the system.
if ($accession){
    my $existing_expt = ArrayExpress::AutoSubmission::DB::Experiment->retrieve(
	    accession       => $accession,
	    is_deleted      => 0,
	);
	unless ($existing_expt){
		die "Error: No experiment with accession number $accession found. Cannot update experiment.\n";
	}	
}

# We need an experiment name that is reasonably unique (IDF name will not be unique)
my $name;
open (my $fh, "<", $startfile);
while (<$fh>){
s/\"//g;
if (/Investigation ?Title\t([^\t]*)/ig){
	    $name=$1;
        chomp $name;
	    last;
	}
}
close $fh;
$name = "Untitled experiment (".date_now.")" unless $name;
	
# Instantiate our Creator object.
my $creator = ArrayExpress::AutoSubmission::Creator->new({
    login           => "bii",
    name            => $name,
    accession       => $accession,
    spreadsheet     => $startfile,
    data_files      => [ @sdrfs, @ARGV ],
    experiment_type => 'BII',
    comment         => 'Submission inserted manually',
    clobber         => $clobber,
});
# Create the experiment
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
