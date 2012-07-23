#!/bin/bash

# Start the MySQL daemon
/sbin/service mysqld start

# Create an empty database for Wordpress to use
/usr/bin/mysql -u root -e "create database ${AUDREY_VAR_mysql_wp_name}"

# Set up MySQL access controls, so the Apache server can get to the database
/usr/bin/mysql -u root -e "grant all on ${AUDREY_VAR_mysql_wp_name}.* to ${AUDREY_VAR_mysql_wp_user}@${AUDREY_VAR_mysql_apache_ip};"
/usr/bin/mysql -u root -e "set password for ${AUDREY_VAR_mysql_wp_user}@${AUDREY_VAR_mysql_apache_ip} = password('${AUDREY_VAR_mysql_wp_pw}');"

# Copy the dbup.rb file to the required location
cp -f dbup.rb /usr/lib/ruby/site_ruby/1.8/facter/dbup.rb
