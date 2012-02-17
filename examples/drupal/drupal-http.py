#!/usr/bin/python

import os
import subprocess
import shutil
import random
import string

chars = string.ascii_uppercase + string.digits + string.ascii_lowercase
salt = ''.join(random.choice(chars) for x in range(43))

filename = "settings.php"
conf_base = "/etc/drupal7/default/"
conf_file = os.path.join(conf_base, filename)

# copy our settings.php to drupal's sites dir
shutil.copyfile(filename, conf_file)

# get the pre-replaced settings.php file
conf = open(conf_file, 'r')
lines = conf.readlines()
conf.close()

var_prefix = "AUDREY_VAR_http"
def audrey_var(var):
  os.environ["%s_%s" % (var_prefix, var)]

# get the audrey vars
drupal_keys = {'db_name_here': audrey_var('db_name'),
               'db_user_here': audrey_var('db_user'),
               'db_pw_here': audrey_var('db_pw'),
               'db_ip_here': audrey_var('db_ip'),
               'drupal_salt_here': salt}

# map the drupal key values in to the config
def sub_drupal_values(line):
  for key, val in drupal_keys.items():
    line = line.replace(key, val)
  return line

lines = map(sub_drupal_values, lines)

# write the conf file back out
conf = open(conf_file, 'w')
conf.write("".join(lines))
conf.close()

# be sure apache is running
subprocess.call(["/sbin/service", "httpd", "stop"])
subprocess.call(["/sbin/service", "httpd", "start"])

# complete the drupal installation
# hostname = subprocess.check_output(["/usr/bin/facter", "ec2_public_hostname"]).strip()
# subprocess.call(["curl", "-d", "weblog_title=AudreyFTW&user_name=admin&admin_password=admin&admin_password2=admin&admin_email=admin@example.com&blog_public=0", "http://%s/wordpress/wp-admin/install.php?step=2" % hostname])
