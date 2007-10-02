#!/usr/bin/env perl -wT
#
# Example instance script for tab2mage web submissions.
#
# $Id: submit.cgi 1595 2007-06-08 13:24:25Z tfrayner $

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use ArrayExpress::AutoSubmission::WebForm;
use ArrayExpress::Curator::Config qw($CONFIG);

my $webapp = ArrayExpress::AutoSubmission::WebForm->new(
    PARAMS => {
	experiment_type  => 'MAGE-TAB',
	spreadsheet_type => 'MAGE-TAB',
	cgi_base         => '/cgi-bin/microarray/magetab.cgi',
	stylesheet       => '/microarray/tab2mage.css',
	intro_html_template    => 'magetab_intro.html',
	upload_html_template   => 'magetab_upload.html',
	template_html_template => 'magetab_template.html',
	sidebar_icons   => [
	    {
		image       => '/microarray/aelogo.png',
		destination => 'http://www.ebi.ac.uk/arrayexpress/',
		alt         => 'ArrayExpress',
	    },
	    {
		image       => '/microarray/MAGETAB_logo_small.png',
		destination => 'http://tab2mage.sourceforge.net/docs/magetab_subs.html',
		alt         => 'MAGE-TAB',
		width       => 100,
	    },
	],
	sidebar_links   => [
	    {
		text        => 'Submitting MAGE-TAB to ArrayExpress',
		destination => 'http://tab2mage.sourceforge.net/docs/magetab_subs.html',
	    },
	    {
		text        => 'MAGE-TAB overview',
		destination => 'http://tab2mage.sourceforge.net/docs/magetab_docs.html',
	    },
	    {
		text        => 'IDF detailed notes',
		destination => 'http://tab2mage.sourceforge.net/docs/idf.html',
	    },
	    {
		text        => 'SDRF detailed notes',
		destination => 'http://tab2mage.sourceforge.net/docs/sdrf.html',
	    },
	    {
		text        => 'MAGE-TAB specification',
		destination => 'http://www.mged.org/mage-tab/',
	    },
	    {
		text        => 'Microarray data submissions',
		destination => 'http://www.ebi.ac.uk/microarray/submissions.html',
	    },
	    {
		text        => 'Query ArrayExpress',
		destination => 'http://www.ebi.ac.uk/arrayexpress/',
	    },
	    {
		text        => 'Microarray group',
		destination => 'http://www.ebi.ac.uk/microarray/',
	    },
	],
    }
);

# Start the CGI script.
$webapp->run();
