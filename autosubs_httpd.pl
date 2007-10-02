#!/usr/bin/env perl
#
# Web server daemon script to provide views onto automated submissions
# processing.
#
# Tim Rayner 2006 EBI Microarray Informatics Team
#
# $Id$
#

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use Proc::Daemon;
use CGI;
use Getopt::Long;

use ArrayExpress::AutoSubmission::DB;

########
# SUBS #
########

sub create_table {

    my ( $methods, $records, $sort_key ) = @_;

    my $cgi = CGI->new;

    my $content = q{};

    $content .= $cgi->start_html(
        -title => 'Curator Submissions Tracking',
        -style => { src => '/style.css' }
    );
    $content .= $cgi->h1('Curator Submissions Tracking (deprecated interface)');

    $content .= $cgi->ul(
        $cgi->li(
            $cgi->a( { href => '/mx_array.html' }, "MIAMExpress Arrays" )
        ),
        $cgi->li(
            $cgi->a(
                { href => '/mx_experiment.html' },
                "MIAMExpress Experiments"
            )
	),
        $cgi->li(
            $cgi->a(
                { href => '/t2m_experiment.html' },
                "Tab2MAGE Experiments"
            )
	),
	$cgi->li(
            $cgi->a( { href => '/t2m_protocol.html' }, "Tab2MAGE Protocols" )
	)
    );

    if ( $methods && scalar @$methods ) {
        my $header_data = q{};
        foreach my $method (@$methods) {
            my $formatted_heading = ucfirst($method);
            $formatted_heading =~ s/_(\w)/q{ } . ucfirst($1)/ge;
            $header_data .= $cgi->th($formatted_heading);
        }
        my $table_header = $cgi->Tr($header_data);

        if ( $records && scalar @$records ) {

	    my @sorted =
		map { $_->[0] }
		reverse sort { $a->[1] <=> $b->[1] }
		map { [ $_, $_->$sort_key ] }
		@$records;

            # Print out the whole table
            my @table_rows;
            foreach my $object (@sorted) {
                my $row_data = q{};
                foreach my $method (@$methods) {
                    my $cell = $object->$method;

                    # Colour up the status column values to highlight them.
                    if ( $method =~ /\bstatus\b/i ) {
                        my $color =
                              ( $cell =~ /\bfail(?:ed|ure|ing)?\b/i ) ? q{red}
                            : ( $cell =~ /\bpass(?:ed|ing)?\b/i )   ? q{green}
                            : ( $cell =~ /\bwarn(?:ed|ings?)?\b/i ) ? q{blue}
                            : q{};
                        $cell = $color
                            ? qq{<font color="$color">$cell</font>}
                            : $cell;
                    }
                    $row_data .= $cgi->td($cell);
                }
                push( @table_rows, $cgi->Tr($row_data) );
            }
            $content
                .= $cgi->table( { border => 1 }, $table_header, @table_rows );
        }

        else {

            # Headings only
            $content .= $cgi->table( { border => 1 }, $table_header );
        }
    }

    $content .= $cgi->end_html;

    return $content;
}

sub mx_array_list {
    my @records = ArrayExpress::AutoSubmission::DB::ArrayDesign->search(
	is_deleted => 0,
    );
    my @headings =
      qw(
      miamexpress_subid
      accession
      name
      miamexpress_login
      status
      data_warehouse_ready
      date_last_processed
      comment
    );
    return ( 'text/html',
        create_table( \@headings, \@records, 'miamexpress_subid' ) );
}

sub mx_experiment_list {
    my @records = ArrayExpress::AutoSubmission::DB::Experiment->search(
	experiment_type => 'MIAMExpress',
	is_deleted      => 0,
    );
    my @headings =
	qw(
	   miamexpress_subid
	   accession
	   name
	   miamexpress_login
	   status
	   data_warehouse_ready
	   date_last_processed
	   checker_score
	   software
	   comment
	   curator
       );
    return ( 'text/html',
        create_table( \@headings, \@records, 'miamexpress_subid' ) );
}

sub t2m_experiment_list {
    my @records = ArrayExpress::AutoSubmission::DB::Experiment->search(
	experiment_type => 'Tab2MAGE',
	is_deleted      => 0,
    );
    my @headings =
	qw(
	   accession
	   name
	   user_id
	   status
	   data_warehouse_ready
	   date_last_processed
	   checker_score
	   software
	   in_curation
	   comment
	   curator
       );
    return ( 'text/html',
        create_table( \@headings, \@records, 'id' ) );
}

sub t2m_protocol_list {
    my @records = ArrayExpress::AutoSubmission::DB::Protocol->search(
	is_deleted => 0,
    );
    my @headings =
	qw(
	   accession
	   user_accession
	   expt_accession
	   name
	   date_last_processed
	   comment
       );
    return ( 'text/html',
        create_table( \@headings, \@records, 'accession' ) );
}

########
# MAIN #
########

my $DEBUG;
GetOptions( "D|debug" => \$DEBUG );

# Run in the background.
unless ($DEBUG) {
    print STDOUT "Starting HTTP Daemon...\n";
    Proc::Daemon::Init;
}

# Set up the http daemon process.
my $port = 8086;
my $httpd = HTTP::Daemon->new( LocalPort => $port )
    or die("Error: cannot bind to port $port: $!");
print STDOUT ( "Started HTTP at " . $httpd->url() . "\n" ) if $DEBUG;

# Ignore child process exits. This should cut down on zombie
# processes.
$SIG{CHLD} = 'IGNORE';

# Hold the stylesheet in memory.
my $stylesheet = join( "\n", <DATA> );

# Supported page links should be enumerated here.
my %dispatch = (
    '/mx_array.html'      => \&mx_array_list,
    '/mx_experiment.html' => \&mx_experiment_list,
    '/t2m_protocol.html'  => \&t2m_protocol_list,
    '/t2m_experiment.html'  => \&t2m_experiment_list,
    '/style.css'          => sub { return ( 'text/css', $stylesheet ) },
);

# Get HTTP requests and respond to them in a forked process.
while ( my $client = $httpd->accept() ) {
    my $pid = fork();
    if ( !$pid ) {

        #### Child process ####
        while ( my $request = $client->get_request() ) {

            my $response = HTTP::Response->new(RC_OK);

            if ( $request->method() eq 'GET' ) {
                if ( my $url = $request->url()->path() ) {

                    # See if the request is in the dispatch table.
                    my ( $type, $content );
                    if ( my $code_ref = $dispatch{$url} ) {
                        ( $type, $content ) = $code_ref->();
                    }

                    # If everything worked, serve up the desired content.
                    if ( $type && $content ) {
                        $response->header( 'Content-Type' => $type );
                        $response->content($content);
                    }

                    # Otherwise, fall back to a basic menu.
                    else {
                        $response->header( 'Content-Type' => 'text/html' );
                        $response->content( create_table() );
                    }
                }
            }
            $client->send_response($response);

            # Log the request.
            print STDOUT (
                $request->method() . "\n" . $request->url()->path() . "\n" )
                if $DEBUG;
        }

        # Clean up.
        $client->close();
        undef($client);
        exit();
        #### End of Child process ####
    }
    #### Parent process ####
}

__DATA__
body {
  font-family: ariel, helvetica, sans-serif;
  line-height: 120%;
  background-color: #ccddff;
}

td, th {
  background-color: #ddeeff;
}

