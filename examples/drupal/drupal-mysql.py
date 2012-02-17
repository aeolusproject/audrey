#!/usr/bin/python

import os
import subprocess
import shutil

var_prefix = "AUDREY_VAR_mysql"

# Look up an audrey var
# AUDREY_VAR_mysql_%var
def audrey_var(var):
  os.environ["%s_%s" % (var_prefix, var)]

def v(var):
  audrey_var(var)

def mysql_cmd(cmd):
  subprocess.call(["/usr/bin/mysql", "-u", "root", "-e", cmd])

# Start mysql
subprocess.call(["/sbin/service", "mysqld", "start"])

# Setup the drupal database
mysql_cmd("create database %s;" % v("db_name"))
mysql_cmd("grant all on %s.* to %s@%s;" % (v("db_name"), v("db_user"), v("apache_ip")))
mysql_cmd("set password for %s@%s = password('%s');" % (v("db_user"), v("apache_ip"), v("db_pw")))

# Write out the dbup fact
# When this fact is readable by audrey-agent, it means that the db is ready
shutil.copyfile('dbup.rb', '/usr/lib/ruby/site_ruby/1.8/facter/dbup.rb')
