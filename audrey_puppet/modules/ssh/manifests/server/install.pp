class ssh::server::install {
  package { "openssh-server":
    require => Class["ssh::server::user"],
  }
}
