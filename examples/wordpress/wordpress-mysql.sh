#!/usr/bin/python

import os
import subprocess
import shutil

subprocess.call(["/sbin/service", "mysqld", "start"])
subprocess.call(["/usr/bin/mysql", "-u", "root", "-e", 
                 'create database %s;' % os.environ['AUDREY_VAR_mysql_wp_name']])
subprocess.call(["/usr/bin/mysql", "-u", "root", "-e", 
                 "grant all on %s.* to %s@%s;" % (
                 os.environ['AUDREY_VAR_mysql_wp_name'],
                 os.environ['AUDREY_VAR_mysql_wp_user'],
                 os.environ['AUDREY_VAR_mysql_apache_ip'] ) ] )
subprocess.call(["/usr/bin/mysql", "-u", "root", "-e", 
                 "set password for %s@%s = password('%s');" % (
                 os.environ['AUDREY_VAR_mysql_wp_user'],
                 os.environ['AUDREY_VAR_mysql_apache_ip'],
                 os.environ['AUDREY_VAR_mysql_wp_pw'] ) ] )
shutil.copyfile('dbup.rb', '/usr/lib/ruby/site_ruby/1.8/facter/dbup.rb')
