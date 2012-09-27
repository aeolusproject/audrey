class configserver {
  service { "configserver":
    name       => "aeolus-configserver",
    hasstatus  => true,
    hasrestart => true,
    ensure     => "running",
  }

  package { "configserver":
    name       => "aeolus-configserver",
    ensure     => installed,
  }

  $config_server_prefix = $config_server_prefix ? {
    ''        => '/',
    default   => $config_server_prefix
  }
  file { "/etc/sysconfig/aeolus-configserver":
    owner   => 'root',
    group   => 'root',
    content => template("configserver/aeolus-configserver.conf.erb"),
    require => Package["configserver"],
    notify  => Service["configserver"],
  }

  file { "/var/lib/aeolus-configserver/":
    ensure  => directory,
    owner   => 'aeolus',
    group   => 'aeolus',
  }

  file { "/var/lib/aeolus-configserver/configs/":
    ensure  => directory,
    require => File['/var/lib/aeolus-configserver/'],
    owner   => 'aeolus',
    group   => 'aeolus',
  }

  file { "/var/lib/aeolus-configserver/configs/oauth/":
    ensure  => directory,
    require => File['/var/lib/aeolus-configserver/configs/'],
    mode    => 0700,
    owner   => 'aeolus',
    group   => 'aeolus',
  }

  file { "/var/lib/aeolus-configserver/configs/oauth/$conductor_key":
    content => $conductor_secret,
    require => File['/var/lib/aeolus-configserver/configs/oauth/'],
    mode    => 0700,
    owner   => 'aeolus',
    group   => 'aeolus',
  }
}
