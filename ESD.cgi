#!/ebi/extserv/bin/perl/bin/perl -T
#
# Example instance script for European Sample Database web submissions.
#
# $Id$


# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use ArrayExpress::AutoSubmission::WebForm;
use ArrayExpress::Curator::Config qw($CONFIG);

my $webapp = ArrayExpress::AutoSubmission::WebForm->new(
    PARAMS => {
	experiment_type  => 'ESD',
	spreadsheet_type => 'MAGE-TAB',
	cgi_base         => '/cgi-bin/microarray/ESD.cgi',
	stylesheet       => '/microarray/tab2mage.css',
	intro_html_template    => 'ESD_intro.html',
	upload_html_template   => 'ESD_upload.html',
	template_html_template => 'ESD_template.html',
	header_html_template => 'ebi_header.html',
	footer_html_template => 'ebi_footer.html',
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
	],
    }
);

# Start the CGI script.
$webapp->run();
