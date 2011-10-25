#!/bin/bash
#
#######################################################################
# katello_start.bash
#
#     This example script is useful for confirming invokation
#     by the Audrey Start Agent and it's environment.
#
#     It simply:
#     logs it's own program name
#     logs it's current working directory
#     logs all command line arguments
#     logs all environment variables with prefix AUDREY_
#
# Input:
#     $1 - The Required Parameters for this instance from the
#          DeployableXML 
#
#     AUDREY_VAR_<> Environment Variables.
#     AUDREY_VAR_jon_agent_jon_server_ip - IP address of JON Server
#
# Returns:
#     0  - On Success
#     !0 - On Failure
#     
# Diagnostics log:
#     $(pwd)/audrey_config.log
#     i.e.:
#     /var/audrey/tooling/user/<service name>/audrey_config.log
#
#######################################################################
LOG="./audrey_tooling.log"

#######################################################################
# log_out
#     Pass output to stdout and the log file to aid debugging.
#
# Input:
#     $1 - Message to log.
#
# Returns:
#     None
#
#######################################################################
function log_out
{
    /bin/echo -e "$1"
    /bin/echo -e "$1" >> $LOG
}

#######################################################################
# main
#######################################################################


log_out "PROGNAME: $0"

log_out "pwd:$(/bin/pwd)"

log_out "\nargs:"
while [ $# -gt 0 ]
do
    log_out "$1"
    shift
done

log_out "\nprintenv AUDREY_*: \n$(printenv | grep AUDREY_)"

exit 0 # Success

