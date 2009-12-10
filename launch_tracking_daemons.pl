#!/usr/bin/perl

#
#
# Script to launch/restart tracking daemons
#
#

use strict;
use Getopt::Long;

use ArrayExpress::Curator::Common qw(date_now);
use ArrayExpress::AutoSubmissions::DB::Pipeline;
use ArrayExpress::AutoSubmissions::DB::DaemonInstance;

# Reaper method to wait for children and update tracking database if they die
$SIG{CHLD} = \&REAPER;
sub REAPER {
    my $pid;

    $pid = waitpid(-1, &WNOHANG);

    if ($pid == -1) {
        # no child waiting.  Ignore it.
    } 
    elsif (WIFEXITED($?)) {
        # Process exited
        my @results = ArrayExpress::AutoSubmissions::DB::DaemonInstance->search( 
            running => 1,
            pid     => $pid, 
        );
        
        my $di = $results[0] or return;
        # FIXME add end_time
        $di->set( running => 0, end_time => date_now );
        $di->update;
    } 
    else {
        #"False alarm on $pid.\n";
    }
    $SIG{CHLD} = \&REAPER;          # in case of unreliable signals
}

my (@pipelines, $restart, $help);

GetOptions(
    "p|pipeline=s" => \@pipelines,
    "r|restart"    => \$restart,
    "h|help"       => \$help,
);

$usage<<END;

END

if ($help){
	print $usage;
	exit;
}

if ($restart){
	"** Restart will kill ALL tracking daemons currently running **\nContinue? (y/n)\n";
	my $answer = <>;
	die unless $answer=~/^y/i;
	
	# Get list of pids from subs tracking.
	my $result = ArrayExpress::AutoSubmissions::DB::DaemonInstance->search( running => 1 );
	
	# kill them all
	my @pids;
	while (my $daemon = $result->next){
		my $pid = $daemon->pid;
		push @pids, $pid;
		kill "USR1", $pid or die "Could not send kill signal to process $pid. $!"; 
	}
	
	# poll every 5 seconds until they are all gone
	my @still_alive;
	TEST: for (0..12){
        unless (@still_alive = grep { kill 0, $_ } @pids ){
        	last TEST;
        }
        sleep 5;
	}
	
	# Die if any are still alive after 1 minute
	if (@still_alive){
		die ("Could not kill all daemons. The following processes were still alive after 1 minute:\n"
		    .join "\n", @still_alive);
	}
	
}

# Get the pipeline objects from names specified by user
my @pipeline_objects;
if(@pipelines){
	foreach my $pl (@pipelines){
        my @results = ArrayExpress::AutoSubmission::DB::Pipeline->search( submission_type => $pl );
        unless (@results){
        	die "Could not find pipeline with name $pl\n";
        }
        push @pipeline_objects, $results[0];
	}
}
else{
	# Or get list of defaults from subs tracking
	my $result = ArrayExpress::AutoSubmission::DB::Pipeline->retrieve_all;
	while (my $pipeline = $result->next){
		for (0..$pipeline->instances_to_start){
			push @pipeline_objects, $pipeline;
		}
	}
}

my @child_pids;
foreach my $pipeline (@pipeline_objects){
	
	# get pipeline parameters from subs tracking
	$submis_type = $pipeline->submission_type;
	
	TYPE: foreach my $daemon qw(exporter_daemon checker_daemon){
        
        my $type = $pipeline->$daemon;		
		next TYPE unless defined($type);
		
		my $pid = fork();
		if ($pid) {
	        # parent
	        push(@child_pids, $pid);
	        # Store pid in subs tracking
	        ArrayExpress::AutoSubmission::DB::DaemonInstance->new({
	        	pipeline_id => $pipeline->id,
	        	daemon_type => $type,
	        	pid         => $pid,
	        	start_time  => date_now,
	        	running     => 1,
	        	user        => getlogin,
	        });
	    }
	    elsif ($pid == 0) {
	        # child
	        # Spawn daemon
	        my $daemon_class = "ArrayExpress::AutoSubmission::Daemon::".$type;
	        eval "use $daemon_class";
	        if ($@){
	        	die "Could not load $daemon_class. $!";
	        }

            # Common daemon atts
	        my %atts = (
	            polling_interval  => $pipeline->polling_interval,
                experiment_type   => $submis_type,
                checker_threshold => $pipeline->checker_threshold,
                autosubs_admin    => $CONFIG->get_AUTOSUBS_ADMIN(),
                accession_prefix  => $pipeline->accession_prefix,
                qt_filename       => $pipeline->qt_filename,	        
	        );

            # Exporter sepcific atts
	        if ($daemon eq "exporter_daemon"){
	        	$atts{pipeline_subdir} = $pipeline->pipeline_subdir;
	        	$atts{keep_protocol_accns} = $pipeline->keep_protocol_accns;
	        }
	        
	        $daemon_class->new(\%atts);
	        $daemon->run;
	        exit(0);
	    } 
	    else {
	        die "Couldn't fork to create $submis_type $type daemon: $!\n";
	    }	
	}
}


