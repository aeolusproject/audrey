#!/bin/bash
#
#   Copyright [2011] [Red Hat, Inc.]
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

usage() {
    echo "usage: aeolus-configserver-setup"
}

# should be run as root
if [ "root" != "$USER" ]; then
    echo "aeolus-configuration-setup must be run as root"
    exit 1
fi

# bail out early if puppet is not installed
PUPPET=$(which puppet)
if [ "x$PUPPET" == "x" ]; then
    echo "Puppet must be installed.  Please install puppet to continue."
    exit 1
fi

MODULE_PATH="/usr/share/aeolus-configserver/configure/puppet/modules"

[ -r "/etc/sysconfig/aeolus-configserver" ] && . /etc/sysconfig/aeolus-configserver
AEOLUS_USER="${AEOLUS_USER:-aeolus}"
AEOLUS_GROUP="${AEOLUS_GROUP:-aeolus}"

###############
## SSL
##
## * Decide whether conductor owns SSL or we need to setup our own
## * Use conductor ssl puppet class for proxy drop file
## * Use configserver ssl puppet class for proxy drop file otherwise
##

conductor_vhost_dir="/etc/httpd/conf.d/aeolus-conductor.d"

# determines if aeolus-conductor has installed a vhost for *:443 in apache
# configs
function check_aeolus_conductor_vhost() {
  if [ -d "${conductor_vhost_dir}" ]; then
    return 0
  else
    return 1
  fi
}

###############
## OAuth
##
## * Decide whether to generate a new admin key
## * Generate key/secret pair if necessary
## * Lookup and use existing key/secret pair otherwise
##

admin_oauth_key_prefix="admin-"
oauth_dir="/var/lib/aeolus-configserver/configs/oauth/"
admin_oauth_glob="${oauth_dir}/${admin_oauth_key_prefix}*"

# determines if the admin oauth credentials have been created already
function check_admin_oauth_exists() {
  if [ "x`ls ${admin_oauth_glob} 2> /dev/null}`" == "x" ]; then
    return 1
  else
    return 0
  fi
}

function get_existing_admin_oauth() {
  declare -a existing_oauth
  existing_oauth[0]=`ls -1 $admin_oauth_glob | head -1`
  existing_oauth[1]=`cat ${existing_oauth[0]}`
  echo "${existing_oauth[@]}"
}

function get_admin_oauth() {
  declare -a oauth_data
  check_admin_oauth_exists
  if [ $? -eq 0 ]; then
    # Generate OAuth key and secret for conductor
    # the argument to -dc is the characters to choose from
    # the argument to -c is the length of the generated string
    oauth_key=`</dev/urandom tr -dc 0-9 | head -c24`
    oauth_data[0]="${admin_oauth_key_prefix}${oauth_key}"
    oauth_data[1]=`</dev/urandom tr -dc A-Za-z0-9 | head -c48`
  else
    oauth_data=( $(get_existing_admin_oauth) )
  fi
  echo "${oauth_data[@]}"
}

###############
## Main
##

case "$1"  in
    -h|--help) usage ; exit 0 ;;
esac

# Setup the admin oauth keys
admin_oauth=( $(get_admin_oauth) )
conductor_key=${admin_oauth[0]}
conductor_secret=${admin_oauth[1]}

# Decide how to setup apache proxy configs
check_aeolus_conductor_vhost
if [ $? -eq 0 ]; then
  ssl_class="conductor::ssl"
else
  ssl_class="ssl"
fi

# Setup some vars for the config server web application URL and context
root_context="/"
app_url="http://localhost:4567/"

# Write out the oauth key and secret
echo ""
echo "Conductor Auth Key: $conductor_key"
echo "Conductor Auth Secret: $conductor_secret"
echo ""
echo -n "*** You need to add this config server information to a "
echo "provider account in conductor. ***"

# Write the puppet manifest out
manifest="""#!/bin/sh

cat <<yaml
---
classes:
    - apache::base
    - apache::${ssl_class}
    - configserver
parameters:
    conductor_key: ${conductor_key}
    conductor_secret: ${conductor_secret}
    config_server_context: ${root_context}
    config_server_url: ${app_url}
yaml"""

manifest_file=$(mktemp)
echo "$manifest" > $manifest_file
chmod 755 $manifest_file

# Run puppet to configure config server
echo "running: echo | $PUPPET --modulepath $MODULE_PATH --external_nodes $manifest_file\
 --node_terminus exec"
echo | $PUPPET --modulepath $MODULE_PATH --external_nodes $manifest_file \
 --node_terminus exec
