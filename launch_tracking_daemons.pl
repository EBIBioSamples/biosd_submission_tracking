#!/usr/bin/perl

#
#
# Script to launch/restart tracking daemons
#
# $Id$

# Next line is a placeholder. Uncomment and edit as necessary, or set PERL5LIB environmental variable
# use lib /path/to/directory/containing/Curator/modules;

use strict;
use Getopt::Long;
use English;
use Carp qw(confess);

use POSIX ":sys_wait_h";
use File::Temp;

use ArrayExpress::Curator::Common qw(date_now);
use ArrayExpress::Curator::Config qw($CONFIG);
use ArrayExpress::AutoSubmission::DB::Pipeline;
use ArrayExpress::AutoSubmission::DB::DaemonInstance;

$|=1;

my (@pipelines, $restart, $kill, $help);

GetOptions(
    "p|pipeline=s" => \@pipelines,
    "r|restart"    => \$restart,
    "h|help"       => \$help,
    "k|kill"       => \$kill,
);

my $usage=<<END;
    Usage: 
      
      To start all default daemons:
      launch_tracking_daemons.pl 
      
      To start specific daemons:
      launch_tracking_daemons.pl -p Tab2MAGE -p MAGE-TAB
      
      To kill all dameons currently known to be running:
      launch_tracking_daemons.pl -k
      
      To kill all running daemons and then restart all default daemons:
      launch_tracking_daemons.pl -r
      
      NB: when using this script take care not to start more than 1 MIAMExpress checker daemon
END

if ($help){
	print $usage;
	exit;
}

if ($restart or $kill){
	print "** This will kill ALL tracking daemons currently running **\nContinue? (y/n)\n";
	my $answer = <>;
	die unless $answer=~/^y/i;
	
	# Get list of pids from subs tracking.
	my $result = ArrayExpress::AutoSubmission::DB::DaemonInstance->search( running => 1 );
	
	# kill them all
	my @pids;
	PID: while (my $daemon = $result->next){
		my $pid = $daemon->pid;

        # Use grep to check that the process we are about to kill
        # has the name we expect it to have
		my $name_suffix = $daemon->pipeline_id->submission_type
		                  ."."
		                  .$daemon->daemon_type;
		my $rc = system("ps $pid | grep $name_suffix");
		
		if ($rc){
		    warn ("Process $pid with name $name_suffix not found. Updating daemon status to not running.\n");
		    $daemon->set( running => 0, end_time => date_now() );
		    $daemon->update();
		    next PID;
		}
        
        push @pids, $pid;
		print "Killing $pid ($name_suffix)\n";
		kill "USR1", $pid or warn "Could not send kill signal to process $pid. $!"; 
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

if ($kill){
	print "Done.\n";
	exit;
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
		if ($pipeline->instances_to_start){
			my $num = $pipeline->instances_to_start - 1;
			for (0..$num){
				push @pipeline_objects, $pipeline;
			}
		}
	}
}

my @child_pids;
foreach my $pipeline (@pipeline_objects){
	
	# get pipeline parameters from subs tracking
	my $submis_type = $pipeline->submission_type;
	
	TYPE: foreach my $daemon qw(exporter_daemon checker_daemon){
        
        my $type = $pipeline->$daemon;		
		next TYPE unless defined($type);
		
		my $pidfile = File::Temp::tempnam($CONFIG->get_AUTOSUBMISSIONS_FILEBASE, "$submis_type.$type.");
		
		my $pid = fork();
		
	    if ($pid == 0) {
	        # child
	        # Spawn daemon
	        $PROGRAM_NAME .= ".$submis_type.$type";
	        my $daemon_class = "ArrayExpress::AutoSubmission::Daemon::".$type;
	        eval "use $daemon_class";
	        if ($@){
	        	die "Could not load $daemon_class. $!, $@";
	        }
	        
	        my $threshold;
	        my $comma_and_space=qr(\s*,\s*);
            foreach my $level (split $comma_and_space, $pipeline->checker_threshold){
            	my $get_level = "get_$level";
            	if ($threshold){
            		$threshold = ($threshold | $CONFIG->$get_level);
            	}
            	else{
            		$threshold = $CONFIG->$get_level;
            	}
            }

            # Common daemon atts
	        my %atts = (
	            polling_interval  => $pipeline->polling_interval,
                experiment_type   => $submis_type,
                checker_threshold => $threshold,
                autosubs_admin    => $CONFIG->get_AUTOSUBS_ADMIN(),
                accession_prefix  => $pipeline->accession_prefix,
                qt_filename       => $pipeline->qt_filename,
                pidfile           => $pidfile,	        
	        );

            # Exporter sepcific atts
	        if ($daemon eq "exporter_daemon"){
	        	$atts{pipeline_subdir} = $pipeline->pipeline_subdir;
	        	$atts{keep_protocol_accns} = $pipeline->keep_protocol_accns;
	        }
	        
	        # MX connection specific atts
	        if ($submis_type eq "MIAMExpress"){
                $atts{autosubs_admin} = $CONFIG->get_MX_AUTOSUBS_ADMIN(),
                $atts{mx_dsn}         = $CONFIG->get_MX_DSN(),
                $atts{mx_username}    = $CONFIG->get_MX_USERNAME(),
                $atts{mx_password}    = $CONFIG->get_MX_PASSWORD(),
                $atts{mx_dbparams}    = $CONFIG->get_MX_DBPARAMS(),
	        }
	        
	        my $daemon_instance = $daemon_class->new(\%atts);
	        $daemon_instance->run;
	        exit(0);
	    } 
		elsif ($pid) {
	        # parent

	        # Sleep for a few secs to allow pid file to be written by child
	        sleep 5;
	        
	        open (my $pid_fh, "<", $pidfile) or die "Could not open temp pid file $pidfile for reading. $!";
	        my @pids = <$pid_fh>;
	        push(@child_pids, $pids[0]);
	        
	        # Store pid in subs tracking      
	        ArrayExpress::AutoSubmission::DB::DaemonInstance->insert({
	        	pipeline_id => $pipeline->id,
	        	daemon_type => $type,
	        	pid         => $pids[0],
	        	start_time  => date_now(),
	        	running     => 1,
	        	user        => getlogin,
	        });
	        
	        unlink $pidfile;
	    }
	    else {
	        die "Couldn't fork to create $submis_type $type daemon: $!\n";
	    }	
	}
}

print "Waiting for child processes...\n";

# Monitor daemon processes
my %dead;
while (1) {
    my @dead_pids = grep { (kill 0, $_) == 0 } @child_pids;

    PID: foreach my $pid (@dead_pids){
    	# Skip if we've already handled this
    	chomp $pid;
    	next PID if $dead{$pid};
        print "$pid is dead\n";    	
    	# Record that the process has died
        
        my @results = ArrayExpress::AutoSubmission::DB::DaemonInstance->search( 
            running => 1,
            pid     => $pid, 
        );
        
        if (my $di = $results[0]){
            $di->set( running => 0, end_time => date_now() );
            $di->update;
        }
        
        $dead{$pid} = 1;
    }
    
    if (scalar(@dead_pids) == scalar(@child_pids)){
    	# They are all dead - we can exit
    	exit;
    }
    sleep 2;
}

