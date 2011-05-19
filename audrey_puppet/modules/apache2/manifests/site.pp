define apache2::site( $admin = "webmaster", $aliases = '', $ensure = 'present', $rails = false, $conf = false, $user = false) {
  $siteroot = "$sites::base_dir/$name"
  $docroot  = $rails ? { true => "$siteroot/public", default => "$siteroot/html"}
  $logroot  = "$siteroot/logs"
  $confroot = "$siteroot/conf"
  file { "/etc/httpd/conf.d/$name.conf":
    mode => "644",
    ensure => $ensure,
    require => Package["httpd"],
    notify => Exec["reload-apache2"],
    content => template("apache2/vhost.conf"),
  } 
  file {$siteroot: ensure => directory}
  file {[$logroot, $docroot]: 
    ensure => directory,
    owner => $user ? { false => undef, default => $user},
    recurse => true,
    mode => 644,
    before => Service["httpd"],
  }

  file {$confroot:
    source  => $conf ? { false => undef, default => $conf},
    recurse => true, force => true,
    ensure  => $conf ? { false => 'absent', default => 'present' },
    notify => Exec["reload-apache2"],
  }
  realize File["/etc/httpd/conf.d/NameVirtualHost.conf"]

  if $rails and $user {
    user{$user: shell => "/bin/false", managehome => true}

    file {["$siteroot/config/environment.rb", "$siteroot/log", "$siteroot/tmp"]: 
      owner => $user,
      mode => 644,
      recurse => true,
      require => User[$user],
      before => Service["httpd"],
    }
  }
 
}
