#!/usr/bin/python

import os
import subprocess

# get the pre rpm's wp conf
conf = open('/etc/wordpress/wp-config.php', 'r')
lines = conf.readlines()
conf.close()

# get the audrey vars
wp_keys = {'database_name_here': 'AUDREY_VAR_http_wp_name',
           'username_here': 'AUDREY_VAR_http_wp_user',
           'password_here': 'AUDREY_VAR_http_wp_pw',
           'localhost': 'AUDREY_VAR_http_mysql_ip'}

# map the wp key values in to the config
def sub_wp_values(line):
  for key, val in wp_keys.items():
    line = line.replace(key, os.environ[val])
  return line

lines = map(sub_wp_values, lines)

# write the conf file back out
conf = open('/etc/wordpress/wp-config.php', 'w')
conf.write("".join(lines))
conf.close()

# be sure apache is running
subprocess.call(["/sbin/service", "httpd", "start"])

# complete the wp installation
hostname = subprocess.check_output(["/usr/bin/facter", "ec2_public_hostname"]).strip()
subprocess.call(["curl", "-d", "weblog_title=AudreyFTW&user_name=admin&admin_password=admin&admin_password2=admin&admin_email=admin@example.com&blog_public=0", "http://%s/wordpress/wp-admin/install.php?step=2" % hostname])
