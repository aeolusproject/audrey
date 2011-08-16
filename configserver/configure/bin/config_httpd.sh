#!/bin/bash

MODULE_PATH="/usr/share/aeolus-configserver/configure/puppet/modules"

[ -r "/etc/sysconfig/aeolus-configserver" ] && . /etc/sysconfig/aeolus-configserver
AEOLUS_USER="${AEOLUS_USER:-aeolus}"
AEOLUS_GROUP="${AEOLUS_GROUP:-aeolus}"

# should be run as root
if [ "root" != "$USER" ]; then
    echo "Please run this configuration tool as root"
    exit 1
fi

PUPPET=$(which puppet)
if [ "x$PUPPET" == "x" ]; then
    echo "Puppet must be installed.  Please install puppet to continue."
    exit 1
fi

HTPASSWD=$(which htpasswd)
if [ "x$HTPASSWD" == "x" ]; then
    echo "The httpd-tools package must be installed.  Install httpd-tools to continue."
    exit 1
fi

USAGE="""
"""

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

echo "$PREAMBLE"
echo -n "Do you wish to continue [y/N]: "
read keep_going
if [ "x$keep_going" == "x" ]; then
    keep_going="Y"
fi
keep_going=$(echo "$keep_going" | tr a-z A-Z)
if [ "Y" != "$keep_going" ]; then
    exit 1
fi

PREAMBLE2="""
There are a few pieces of information to collect.  Some of the information
provides default values. The default values are enclosed in square brackets
after the propmt, such as:

  Enter the root context [/]:

In this case, "/" is the default used for the root context.

"""


# Collect password
PASSWORD_INFO="""

Please provide the username and password information for the Config Server.
These same credentials will have to be supplied to the Cloud Engine when
entering data for this Config Server associated with a Provider Account.

"""
echo "$PASSWORD_INFO"
try_again=true
while [ $try_again == true ]; do
    echo -n "Enter username: "
    read user
    echo -n "Enter password: "
    read -s pass
    echo ""
    echo -n "Confirm password: "
    read -s pass2
    echo ""

    if [ "$pass" != "$pass2" ]; then
        echo "The password entries do not match.  Please try again."
    else
        try_again=false
    fi
done
echo -n " ... creating htpasswd file for Apache Basic Auth "
htpasswd_file="/var/lib/aeolus-configserver/htpasswd"
sudo -u $AEOLUS_USER touch $htpasswd_file # create the file as the aeolus user
$HTPASSWD -b $htpasswd_file $user $pass
echo "... Done"

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

echo "Htpasswd File: $htpasswd_file"
echo "Root context: $root_context"
echo "App URL: $app_url"

manifest_file=$(mktemp)

manifest="""#!/bin/sh

cat <<yaml
---
classes:
    - apache::base
    - apache::ssl
    - apache::auth
    - configserver
parameters:
    htpasswd_file: ${htpasswd_file}
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
