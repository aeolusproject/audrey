# This class installs the apache2 service
# Ensure that there is no network user called apache before installing
# this is a CentOS 5 compatable (e.g. apache 2.2) manifest.
class apache2::common {
  group {"apache": ensure => present, require => Package["httpd"]}
  user  {"apache": ensure => present, home => "/var/www",
    managehome => false, membership => minimum, groups => [],
    shell => "/sbin/nologin", require => Package["httpd"], 
  }
  package { "httpd":}

  service { "httpd" : ensure => "running", subscribe  => Package["httpd"] }

  exec { "reload-apache2":
    command => "/etc/init.d/httpd reload",
    onlyif => "/usr/sbin/apachectl -t",
    require => Service["httpd"],
    refreshonly => true,
  }

  file{
    "/etc/httpd/conf/httpd.conf":
# JJV      source  => ["puppet:///apache2/etc/httpd/conf/httpd.conf.${lsbmajdistrelease}","puppet:///apache2/etc/httpd/conf/httpd.conf.6"],
      content => template("apache2/httpd.conf.6.erb"),
      mode    => 0644,
      notify  => Exec["reload-apache2"],
      require => Package["httpd"];
  #ensure that only managed apache file are present - commented out by default
    "/etc/httpd/conf.d":
      source  => "puppet:///apache2/empty",
      ensure  => directory, checksum => mtime,
      recurse => true, purge => true, force => true,
      mode    => 0644,
      notify  => Exec["reload-apache2"],
      require => Package["httpd"]
  }

  @file{"/etc/httpd/conf.d/NameVirtualHost.conf":
    content => "NameVirtualHost *\n"
  }

}
