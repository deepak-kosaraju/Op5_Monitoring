##### Usage,

```
./check_mon_status.pl 

 Ops... I am need something to help. look usage below..

Copyright (c) 2011 Deepak Kosaraju
        
        ## Dependencies:- Perl module Mail::Mailer to be installed to send emails ##
        
        Helps to monitor the status of Op5 instances in both Distributed and Stanlone Environment, for now it is only helps to monitor the Distributed setup between poller and master, but not master with peer master. Health Status of pollers in Distributed Enviornment is monitored by this watchdog Heatlh Check wrapper via cron job. At any point in time if poller (or) master instance are INACTIVE this Selfheal wrapper will attempt to restart the monitoring instances that are INACTIVE, if it fails to selfheal an email notificaiton is sentout to supplied email id's
        
#### NOTE: RECOVERY EMAIL's ARE ONLY SENT TO EMAIL THAT IS FIRST IN THE LIST THAT IS FEEDED WITH -e OPTION ###
        
** Add following cron entry to a file in '/etc/cron.d/mon_status **

        
####
*/5 * * * * root /opt/plugins/custom/check_mon_status -e < place email id's here>
####

Usage: ./check_mon_status.pl [-e <email address | multiple addresses can be seprate by ,>]
        
        -e  < All emails who need to get notifications separated by , >
        
        -t | --timeout <default is 180sec>
        
        -v | --verbose
        
        -h | --help

```
