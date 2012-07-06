#!/bin/bash

# Dump the working environment environment to a log file (useful for debugging)
env > /var/log/audrey_environment.log

# Add the MySQL node's settings to the Wordpress configuration file
sed -i -e "s/database_name_here/${AUDREY_VAR_http_wp_name}/" /etc/wordpress/wp-config.php
sed -i -e "s/username_here/${AUDREY_VAR_http_wp_user}/" /etc/wordpress/wp-config.php
sed -i -e "s/password_here/${AUDREY_VAR_http_wp_pw}/" /etc/wordpress/wp-config.php
sed -i -e "s/localhost/${AUDREY_VAR_http_mysql_ip}/" /etc/wordpress/wp-config.php

# Let Apache use remote databases (an SELinux permission)
/usr/sbin/setsebool -P httpd_can_network_connect_db 1

# Start the Apache http daemon
/sbin/service httpd start

# Figure out which virtualisation platform we're running on
if [ -f /etc/sysconfig/cloud-info ]
then
  source /etc/sysconfig/cloud-info
fi

# Retrieve an IP address people can connect to
if [ "$CLOUD_TYPE" = "ec2" ]
then
  # We're running in EC2, so get the public address
  HOSTADDRESS=`/usr/bin/facter ec2_public_hostname`
else
  # We're not running in EC2, so just grab any ip address
  HOSTADDRESS=`/usr/bin/facter ipaddress`
fi

# Run the Wordpress installer, passing all the values it needs
curl -d "weblog_title=AudreyFTW&user_name=admin&admin_password=admin&admin_password2=admin&admin_email=admin@example.com&blog_public=0" "http://${HOSTADDRESS}/wordpress/wp-admin/install.php?step=2" > /var/log/audrey_curl.log

# Print useful info to the Audrey log
echo Wordpress should now be available at http://${HOSTADDRESS}/wordpress
