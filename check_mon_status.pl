#!/usr/bin/perl -w
##############################################################################
# check_mon_status                       Version 1.1                         #
# Deepak Kosaraju                 		deepak.kosaraju1@gmail.com           #
# Created:03-13-2012                 Last Modified:03-13-2012                #
##############################################################################

use strict;
use Sys::Hostname;
use Getopt::Long;
use Mail::Mailer;
use vars qw($verbose $help $p_dir $type $start $clean $poller @pollers @failed @pass $inactive @inactive @refused);
use vars qw($email $mailer $body $status $alert);
    
##############################################################################
# Global Status Variable                                                     #
##############################################################################
my $PROGNAME = "$0";
$PROGNAME =~ s/.*\/(check_.*)/$1/;
my $PROGVERSION="1.1";
my $log_file = '/opt/monitor/var/monitor.log';
my $suenv = 'su - monitor -c';

# Setting Timeout Value Default is 10sec #
my $timeout = '180';

Getopt::Long::Configure('bundling');
GetOptions (
	    "h"   => \$help, "help"   => \$help,	
        'e:s' => \$email, "email:s" => \$email, 
	    't:i' => \$timeout, "timeout:i" => \$timeout,
	    'v' => \$verbose, "verbose" => \$verbose
            );

if ($help) {
        usage();
        exit(0);
}

$SIG{'ALRM'} = sub {
	print "$PROGNAME timedout in $timeout sec\n";
};
alarm($timeout);

print "My restart user is: $suenv\t My LOGFILE is: $log_file\t My TIMEOUT is: $timeout\n" if($verbose);

$p_dir = '/usr/bin/mon';


	if (!$email){
	print "\n Ops... I am need something to help. look usage below..\n\n";
	usage();
	exit(255);
}
	
main ();
	
sub main {
		if ( -e "$p_dir" ){
				open(NODES,"$p_dir node list --type=poller|") || die "Failed $!\n";
				foreach(<NODES>){
					print "Poller is: $_" if($verbose);
					push @pollers, $_;
					}
				close(NODES);
				restart();
			}
		else {
			print "UNKNOWN: Check if $p_dir exist and has execute permissions.\n";
			exit(3);
		}
}
sub mon {
	open(MON,"$p_dir node status |") || die "Failed: $!\n";
 while (<MON>) {
	if ($_ =~ /INACTIVE/){
	push(@inactive, $_ =~ /#\d+:\s(\S+).*?\(INACTIVE\)/);
	}
}
 close(MON);
}

sub restart {
mon();
if (@inactive) {
	 print "Following op5 monitors are down: @inactive so attempting to restart...\n" if($verbose);
	 foreach (@inactive){
	 if ($_ =~ /Local/){
		master($_);
	 }
	 else {
		poller($_);
	 }
	 }
	 }
 		else {
	 	print "All Monitoring Instance are up and running\n";
		exit(0)
 		}
		
}

if(scalar @pass == scalar @inactive){
	($email) = $email =~ m/(\S+)?,.*/;
	print "Sending email to: $email\n";
	print "All ".scalar @inactive." INACTIVE instances are self healed, instances are @pass\n";
	mail('OK','SUCCESS',"All ".scalar @inactive." INACTIVE instances are self healed by restart ACTIVITY for following Op5 Instances: @pass. For more information \"tail $log_file\" on ".hostname);
	exit(0);
}
elsif(@pass){
	print "Sending email to: $email\n";
	print "Out of ".scalar @inactive." only ".scalar @pass." INACTIVE instances are self healed, instances are @pass\n";
	mail('CRITICAL','PARTIAL SUCCESS',"Out of ".scalar @inactive." only ".scalar @pass." INACTIVE instances are self healed, instances SUCCESSFULLY recovered are: @pass. For more information \"tail $log_file\" on ".hostname);
}
if(@refused){
	print "Sending email to: $email\n";
	print "Self healing restart ACTIVITY was REFUSED by following Op5 Instances: @refused\n";
	mail('CRITICAL','REFUSED',"Self healing Restart ACTIVITY was REFUSED by following Op5 Instances: @refused. For more information \"tail $log_file\" on ".hostname);
}
if(@failed){
	print "Sending email to: $email\n";
	print "Self healing restart ACTIVITY was FAILED by following Op5 Instances: @failed\n";
	mail('CRITICAL','FAILED',"Self healing restart ACTIVITY was FAILED for following Op5 Instances: @failed. For more information \"tail $log_file\" on ".hostname);
}

sub master {
	$clean = `$suenv "$p_dir stop 2> /dev/null"`;
	$start = `$suenv "$p_dir start 2> /dev/null"`;
		if ($start =~ /monitor is running with pid (\d+)/){
			print"\t Well self healed Master Instance and its running as $1 pid\n" if($verbose);
			logger("## ACTIVITY PASS for $_##\nResults are:\n $start");
			push @pass, $_;
		}
		else{
			print"\t cannot start monitoring on $_ Master instance" if($verbose);
			logger("## ACTIVITY FAILED for $_##\nResults are:\n $start");
			push @failed, $_;
		}
}

sub poller {
	$poller = shift; 
	$clean = `$suenv "$p_dir node ctrl $poller -- mon stop 2> /dev/null"`;
	$start = `$suenv "$p_dir node ctrl $poller -- mon start 2> /dev/null"`;
		if ($start =~ /monitor is running with pid (\d+)/){
			print"\t Well self healed monitoring for $poller instance and its running as $1 pid\n" if($verbose);
			logger("## ACTIVITY PASS for $_##\nResults are:\n $start");
			push @pass, $_;
		}
		elsif ($start =~ /ssh exited with return code \d+/){
			print"\t SSH issue for $poller instance\n" if($verbose);
			logger("## ACTIVITY REFUSED for $_##\nResults are:\n $start");
			push @refused, $_;
		}
		else{
			print"\t Cannot Start Monitoring on $poller instance\n" if($verbose);
			logger("## ACTIVITY FAILED for $_##\nResults are:\n $start");
			push @failed, $_;
		}
}

sub logger {
	my $msg = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    $year += 1900;
    $mon++;

    my $ds = sprintf("%4d-%2.2d-%2.2d",$year,$mon,$mday);
    my $ts = sprintf("%2.2d:%2.2d:%2.2d",$hour,$min,$sec);
    
    if($verbose) { print "$ds $ts ($$) $msg\n"; }
	open(LOG, "> $log_file") or die "Can't open $log_file : $!";
    print LOG "$ds $ts ($$) $msg\n";
    close(LOG);
}

sub mail{
	$alert = shift;
	$status = shift;
	$body = shift;
	$mailer = Mail::Mailer->new("sendmail"); $mailer->open({From	=> $ENV{'LOGNAME'}."@".hostname,
								To	=> "$email",
								Subject => "$alert: Op5 Self Healing was $status ",
								})
					or die "Can't open: $!\n";
				print $mailer $body;
				$mailer->close() || die "Couldn't send email to $email list: $!\n";
}

sub usage {
	print <<EOF;
Copyright (c) 2011 Deepak Kosaraju
	
	## Dependencies:- Perl module Mail::Mailer to be installed to send emails ##
	
	Helps to monitor the status of Op5 instances in both Distributed and Stanlone Environment, for now it is only helps to monitor the Distributed setup between poller and master, but not master with peer master. Health Status of pollers in Distributed Enviornment is monitored by this watchdog Heatlh Check wrapper via cron job. At any point in time if poller (or) master instance are INACTIVE this Selfheal wrapper will attempt to restart the monitoring instances that are INACTIVE, if it fails to selfheal an email notificaiton is sentout to supplied email id's
	
#### NOTE: RECOVERY EMAIL's ARE ONLY SENT TO EMAIL THAT IS FIRST IN THE LIST THAT IS FEEDED WITH -e OPTION ###
	
** Add following cron entry to a file in '/etc/cron.d/mon_status **
	
####
*/5 * * * * root /opt/plugins/custom/check_mon_status -e < place email id's here>
####
  
Usage: ./$PROGNAME [-e <email address | multiple addresses can be seprate by ,>]
	
	-e  < All emails who need to get notifications separated by , >
	
	-t | --timeout <default is 180sec>
	
	-v | --verbose
	
	-h | --help

EOF
	  exit(3);
}
