Package {ensure => installed}
File { owner => root, group => root, mode => 444 }
Service { ensure => running, enable => true, hasstatus => true, hasrestart => true}

