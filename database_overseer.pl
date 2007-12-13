#!/usr/bin/env perl
#
# Script to perform periodic checks and maintenance on the
# autosubmissions database. Tasks include:
#
# 1. Query database for all Tab2MAGE experiments which have data
# uploaded but appear to be abandoned, email submitter and ask them to
# complete.
#
# [more to be added as necessary]
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use warnings;

use MIME::Lite;
use Date::Manip qw(ParseDate DateCalc Delta_Format);
use Getopt::Long;
require ArrayExpress::AutoSubmission::DB::Experiment;
use ArrayExpress::Curator::Common qw(date_now);
use ArrayExpress::Curator::Config qw($CONFIG);

sub email_reminder {

    my $submission = shift;

    my $user     = $submission->user_id()->name();
    my $type     = $submission->experiment_type();
    my $expt     = $submission->name();
    my $mailbody = (<<"MAILBODY");
Dear $user,

We are emailing you to query the status of your ongoing $type
data submission, "$expt".

Our records indicate that it has now been longer than a week since you
last edited your experiment, and that you have successfully uploaded
both a spreadsheet and accompanying data files. If your submission is
now complete, please return to it and click on the final "submit" button
to indicate to us that it is ready for processing. Until this is done,
we will assume that your submission is not yet finished to your
satisfaction.

Best regards,

The ArrayExpress Curation Team
MAILBODY

    my $mail = MIME::Lite->new(
        From     => $CONFIG->get_AUTOSUBS_CURATOR_EMAIL(),
        To       => $submission->user_id()->email(),
        Subject  => "$type submission follow-up: $expt",
        Encoding => 'quoted-printable',
        Data     => $mailbody,
        Type     => 'text/plain',
    );

    # Use the CONFIG SMTP server, if set.
    if ( my $server = $CONFIG->get_AUTOSUBS_SMTP_SERVER() ) {
	$mail->send('smtp', $server)
	    or die("Error sending reminder email: $!");
    }
    else {
	$mail->send()
	    or die("Error sending reminder email: $!");
    }

    return;

}

########
# MAIN #
########

my $help_wanted;
GetOptions("h|help" => \$help_wanted,);

if ($help_wanted) {

    print (<<"USAGE");

    Usage: $0

This script is designed to be run as a cron job; it performs various periodic
maintenance tasks on the autosubmissions database.

USAGE

    exit 255;
}

# Check for submissions that are (a) over a week since last edited,
# (b) have both data files and spreadsheet uploaded, (c) are not
# in_curation, and (d) have no date_last_processed or
# date_last_processed is over a month ago. Email submitter to check
# they haven't forgotten something, and set date_last_processed to
# now.

my $expt_iterator
    = ArrayExpress::AutoSubmission::DB::Experiment->search(
	is_deleted      => 0,
	in_curation     => 0,
	experiment_type => 'Tab2MAGE',
    );

SUBMISSION:
while ( my $submission = $expt_iterator->next() ) {

    # Skip clearly unfinished submissions.
    unless ( scalar $submission->spreadsheets()
        && scalar $submission->data_files() ) {
        next SUBMISSION;
    }

    # Skip test submissions, and subs without users.
    my $user = $submission->user_id();
    if ( ! $user || ( $user->login() eq 'test' ) ) {
	next SUBMISSION;
    }

    my $then = ParseDate( $submission->date_last_edited() );
    next SUBMISSION unless $then;

    my $now = ParseDate( date_now() );
    die("Error parsing date today!") unless $now;

    my $delta = DateCalc( $then, $now, 1 );

    # Time elapsed in weeks.
    my $elapsed_weeks = Delta_Format( $delta, 'approx', 2, '%wt' );

    # Over a week since last edit.
    if ( $elapsed_weeks > 1 ) {
        my $last = ParseDate( $submission->date_last_processed() );

        my $elapsed_months;
        if ($last) {
            my $procdelta   = DateCalc( $last, $now, 1 );
            $elapsed_months = Delta_Format( $procdelta, 'approx', 2, '%Mt' );
        }

        # Either never processed, or over a month since last done.
        if ( ! $last || ( $elapsed_months > 1 ) ) {

	    # Make a note for cron feedback to admin.
	    print STDOUT (
		"Emailing ",
		$user->login(),
		" concerning submission ",
		$submission->name(),
		"\n",
	    );

            # Send the email, note the date.
            email_reminder($submission);
	    my $date = date_now();
            $submission->set(
		'date_last_processed' => $date,
		'comment'             => "Emailed reminder on $date\n\n"
		                            . ($submission->comment() || q{}),
	    );
            $submission->update();
        }
    }
}
