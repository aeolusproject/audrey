class ssh::server::service {
  service { "sshd":
    require => Class["ssh::server::install"],
    subscribe => Class["ssh::server::config","ssh::server::user"],
  }
}
