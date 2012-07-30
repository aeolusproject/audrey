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


PREAMBLE2="""
There are a few pieces of information to collect.  Some of the information
provides default values. The default values are enclosed in square brackets
after the propmt, such as:

  Enter the root context [/]:

In this case, "/" is the default used for the root context.

"""

# Generate OAuth key and secret for conductor
# the argument to -dc is the characters to choose from
# the argument to -c is the length of the generated string
conductor_key=`</dev/urandom tr -dc 0-9 | head -c24`
conductor_secret=`</dev/urandom tr -dc A-Za-z0-9 | head -c48`

# Collect the Config Server application context
CONTEXT_INFO="""

Please provide the web application root context for the Config Server.  This is
the context that clients will use to access the Config Server.  For instance, if
the root context is "configserver", then the URL for the Config Server will be:

  https://\$HOSTNAME:443/configserver

"""
#echo "$CONTEXT_INFO"
#echo -n "Enter the root context [/]: "
#read root_context
if [ "x$root_context" == "x" ]; then
    root_context="/"
fi

# Collect the Config Server application URL
URL_INFO="""

Please provide the web application URL where the Config Server is currently
running on this server.  If the Config Server was installed from an RPM, then
this will typically be:

  http://localhost:4567/

The provided URL should be a fully qualified URL, providing the scheme,
hostname, and port:  http://HOSTNAME:PORT/

"""
echo "$URL_INFO"
echo -n "Enter the application URL [http://localhost:4567/]: "
read app_url
if [ "x$app_url" == "x" ]; then
    app_url="http://localhost:4567/"
fi

echo "Root context: $root_context"
echo "App URL: $app_url"
echo "Conductor Auth Key: $conductor_key"
echo "Conductor Auth Secret: $conductor_secret"
echo "\n\n*** You need to add this config server information to a ***"
echo "*** provider account in conductor.                      ***"
manifest_file=$(mktemp)

manifest="""#!/bin/sh

cat <<yaml
---
classes:
    - apache::base
    - apache::ssl
    - configserver
parameters:
    conductor_key: ${conductor_key}
    conductor_secret: ${conductor_secret}
    proxy_type: \"apache\"
    config_server_context: ${root_context}
    config_server_url: ${app_url}
yaml"""
echo "$manifest" > $manifest_file
chmod 755 $manifest_file

echo "running: echo | $PUPPET --modulepath $MODULE_PATH --external_nodes $manifest_file\
 --node_terminus exec"

echo | $PUPPET --modulepath $MODULE_PATH --external_nodes $manifest_file \
 --node_terminus exec
