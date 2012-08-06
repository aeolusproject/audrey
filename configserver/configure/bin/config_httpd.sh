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
#  limitations under the License.
#

PREAMBLE="""
This script will help you configure Apache as a proxy for a Config Server.
Typically this is only useful if you are not familiar with Apache
configurations and modules, specifically with mod_proxy, mod_auth_basic, and
mod_ssl.

Also, this configuration tool assumes that you are not currently running Apache
for any purposes on this server.  This configuration tool will create a Named
Virtual Host for *:443.  If this server is currently using Apache to serve
secure pages on port 443, then this tool should not be used.

"""

# Determine whether running on an interactive tty (or a pipe)
isatty(){
    stdin="$(ls -l /proc/self/fd/0)"
    stdin="${stdin/*-> /}"

    if [[ "$stdin" =~ ^/dev/pts/[0-9] ]]; then
        return 0 # terminal
    else
        return 1 # pipe
    fi
}

usage()
{
cat << EOF

usage: aeolus-configserver-setup [-h|--help]

${PREAMBLE}

optional arguments:
  -h, --help            show this help message and exit

EOF
}

# use case to simplify supporting -h and --help
case "$1"  in
    -h|--help) usage ; exit 1 ;;
esac

MODULE_PATH="/usr/share/aeolus-configserver/configure/puppet/modules"

[ -r "/etc/sysconfig/aeolus-configserver" ] && . /etc/sysconfig/aeolus-configserver
AEOLUS_USER="${AEOLUS_USER:-aeolus}"
AEOLUS_GROUP="${AEOLUS_GROUP:-aeolus}"

# should be run as root
if [ "root" != "$USER" ]; then
    echo "aeolus-configuration-setup must be run as root"
    exit 1
fi

PUPPET=$(which puppet)
if [ "x$PUPPET" == "x" ]; then
    echo "Puppet must be installed.  Please install puppet to continue."
    exit 1
fi

## is this config server being installed alongside a conductor installation?
puppetclass="ssl"
root_context="/"
if [ -d "/etc/httpd/conf.d/aeolus-conductor.d" ]; then
    puppetclass="conductor"
    root_context="/configserver/"
else
    echo "$PREAMBLE"
    echo -n "Do you wish to continue [y/N]: "
    if isatty ; then
        while read keep_going ; do
            if [[ $keep_going == [Yy] ]]; then
                break
            elif [[ $keep_going == [Nn] ]] || [[ "n$keep_going" == "n" ]]; then
                # catches the "empty" answer and defaults to "no"
                exit 1
            else
                echo -n "Do you wish to continue [y/N]: "
                continue
            fi
        done
    else
        echo y
    fi
fi

# Generate OAuth key and secret for conductor
# the argument to -dc is the characters to choose from
# the argument to -c is the length of the generated string
conductor_key=`</dev/urandom tr -dc 0-9 | head -c24`
conductor_secret=`</dev/urandom tr -dc A-Za-z0-9 | head -c48`


manifest_file=$(mktemp)
manifest="""#!/bin/sh

cat <<yaml
---
classes:
    - apache::${puppetclass}
    - configserver
parameters:
    conductor_key: ${conductor_key}
    conductor_secret: ${conductor_secret}
    config_server_context: ${root_context}
    config_server_url: http://localhost:4567/
yaml"""
echo "$manifest" > $manifest_file
chmod 755 $manifest_file

echo -e "\nrunning: echo | $PUPPET --modulepath $MODULE_PATH --external_nodes $manifest_file\
 --node_terminus exec"

echo | $PUPPET --modulepath $MODULE_PATH --external_nodes $manifest_file \
 --node_terminus exec

endpoint="https://FQDN${root_context} (where FQDN is the fully qualified domain name of this server)"

echo -e "\n********************************"
echo -n "Use the following information in Conductor to register this "
echo -e "configserver with a provider account.\n"
echo "Endpoint:  $endpoint"
echo "Key:       $conductor_key"
echo "Secret:    $conductor_secret"
echo "********************************"
