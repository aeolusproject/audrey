import "configserver"

class apache {
  class variables {
    $httpd_log_level = $httpd_log_level ? {
      ''        => 'debug',
      default   => $httpd_log_level
    }
    $htpasswd_file = $htpasswd_file ? {
      ''        => "/etc/sysconfig/aeolus-configserver-passwd",
      default   => $htpasswd_file
    }
    $config_server_context = $config_server_context ? {
      ''        => '',
      default   => $config_server_context
    }
    $config_server_url = $config_server_url ? {
      ''        => 'http://localhost:4567/',
      default   => $config_server_url
    }
    $proxy_type = $proxy_type ? {
      ''        => 'apache',
      default   => $proxy_type
    }

  }

  class base {
    package { "apache":
      name => "httpd",
      ensure => installed,
    }

    exec { "graceful-apache":
      command => "/sbin/service httpd graceful",
      refreshonly => true,
      require => Package["apache"],
    }
  }

  class ssl {
    include apache::variables

    $pk_file="/etc/pki/tls/private/config-server.key"
    $cert_file="/etc/pki/tls/config-server.crt"
    package { ["openssl", "openssh"]:
      ensure => installed,
    }

    package { "mod_ssl":
      ensure => installed,
      require => Package["apache"],
      notify => Exec["graceful-apache"],
    }

    exec { "pk-gen":
      command => "/usr/bin/ssh-keygen -t rsa -f ${pk_file} -N ''",
      creates => "$pk_file",
      require => Package["mod_ssl"],
      notify => Exec["graceful-apache"],
    }

    exec { "sign-request":
      command => "/usr/bin/openssl req -batch -new -key ${pk_file} -out /etc/pki/tls/config-server.csr",
      creates => "/etc/pki/tls/config-server.csr",
      require => Exec["pk-gen"],
    }

    exec { "cert":
      command => "/usr/bin/openssl x509 -req -days 365 -in /etc/pki/tls/config-server.csr -signkey ${pk_file} -out ${cert_file}",
      creates => "$cert_file",
      require => Exec["sign-request"],
      notify => Exec["graceful-apache"],
    }

    file { "vhost-443":
      name => "/etc/httpd/conf.d/aeolus-configserver-vhost443.conf",
      mode => 0644, owner => root, group => root,
      ensure => present,
      content => template("apache/vhost443.erb"),
      require => Package["mod_ssl"],
      notify => Exec["graceful-apache"],
    }

    # The aeolus-configserver-vhost443.conf file allows for additional configs
    # for the vhost to be placed in the following directory
    file { 'vhost-443-addl':
      name => "/etc/httpd/conf.d/cs443",
      ensure => directory,
      mode => 0644, owner => root, group => root,
      require => Package["apache"],
    }
  }

  class vhost80 {
    file { 'vhost-80':
      name => "/etc/httpd/conf.d/aeolus-configserver-vhost80.conf",
      mode => 0644, owner => root, group => root,
      ensure => present,
      content => template("apache/vhost80.erb"),
      require => Package["apache"],
      notify => Exec["graceful-apache"],
    }

    # The aeolus-configserver-vhost80.conf file allows for additional configs
    # for the vhost to be placed in the following directory
    file { 'vhost-80-addl':
      name => "/etc/httpd/conf.d/cs80",
      ensure => directory,
      mode => 0644, owner => root, group => root,
      require => Package["apache"],
    }
  }

  class auth {
    include apache::variables

    file { "http-auth":
      name => "/etc/httpd/conf.d/cs443/auth.conf",
      mode => 0644, owner => root, group => root,
      ensure => present,
      content => template("apache/auth_config.erb"),
      require => Package["apache"],
      notify => Exec["graceful-apache"],
    }

    file {"configserver-proxy-sysconfig":
      name => "/etc/sysconfig/aeolus-configserver-proxy",
      mode => 0644, owner => root, group => root,
      ensure => present,
      content => template("apache/aeolus-configserver-proxy.erb"),
      require => Package["configserver"],
      notify => Service["configserver"],
    }
  }
}
