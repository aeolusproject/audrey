#!/bin/bash
#
#######################################################################
# katello_start.bash
#
#     This "Audrey tooling" script is responsible for creating the
#     JSON "facts" file: /etc/rhsm/facts/aeolus.facts
#
#     With the content of the form: {"fact1": "value1","fact2": "value2"}
#     {"instance_uuid":"<instance UUID>","image_uuid":"<image UUID>"}
#
#     NOTE:
#     Currently the image UUID is not available so only the instance
#     UUID will be stored.
#
#     It will be invoked by the Audrey Start Agent which must be
#     built into the launching image.
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

AUDREY_LOG="/var/log/audrey.log"
LOG="./audrey_tooling.log"
DEST_DIR="/etc/rhsm/facts"
FACTS_FILE="${DEST_DIR}/aeolus.facts"

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
    /bin/echo "$1"
    /bin/echo "$1" >> $LOG
}

#######################################################################
# main
#
#     This "Audrey tooling" script is responsible for creating the
#     JSON "facts" file: /etc/rhsm/facts/aeolus.facts
#
#     With the content of the form: {"fact1": "value1","fact2": "value2"}
#     {"instance_uuid":"<instance UUID>","image_uuid":"<image UUID>"}
#
#     NOTE:
#     Currently the image UUID is not available so only the instance
#     UUID will be stored.
#
#     It will be invoked by the Audrey Start Agent which must be
#     built into the launching image.
#
# Logic Flow:
#
#     Log provided arguments to aid diagnosing issues.
#     Create the destination directory
#     Create the destination directory.
#     Verify the audrey log file exists.
#     Parse the instance UUID from the Audrey Log.
#     Populate the aeolus facts file.
#     Display the created facts file.
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

log_out "Audrey User Config PROGRAM: $0"

# Log provided arguments to aid diagnosing issues.
while [ $# -gt 0 ]
do
    log_out "arg ${cnt} --->$1<---"
    (( cnt=cnt + 1 ))
    shift
done

# Create the destination directory
log_out "Create the destination directory."
/bin/mkdir -p ${DEST_DIR}
cmd_result=$?
if [[ ${cmd_result} != 0 ]]; then
    log_out "ERROR: Failed to create directory ${DEST_DIR}"
    exit ${cmd_result} # Error
fi

# Verify the audrey log file was created
log_out "Verify the audrey log file exists."
if ! [[ -f ${AUDREY_LOG} ]]; then
    log_out "ERROR: File not Found ${AUDREY_LOG}"
    exit 2 # Error file not found.
fi

# Parse the instance UUID from the Audrey Log
log_out "Parse the instance UUID from the Audrey Log."
UUID=$(/bin/grep "UUID" ${AUDREY_LOG} | /bin/sed 's/^.*UUID:[	, ]*//')
cmd_result=$?
if [[ ${cmd_result} != 0 ]]; then
    log_out "ERROR: Failed to parse UUID from ${AUDREY_LOG}"
    exit ${cmd_result} # Error
fi

# Populate the aeolus facts file.
log_out "Populate the aeolus facts file: ${FACTS_FILE}"
/bin/echo "{\"instance_uuid\":\"${UUID}\"}" > ${FACTS_FILE}
cmd_result=$?
if [[ ${cmd_result} != 0 ]]; then
    log_out "ERROR: Failed to populate facts file: ${FACTS_FILE}"
    exit ${cmd_result} # Error
fi

# Display the created facts file.
log_out "Display the created facts file: ${FACTS_FILE}"
/bin/cat ${FACTS_FILE}
cmd_result=$?
if [[ ${cmd_result} != 0 ]]; then
    log_out "ERROR: Failed to display facts file: ${FACTS_FILE}"
    exit ${cmd_result} # Error
fi

log_out "Success - Exiting"
exit 0 # Success


