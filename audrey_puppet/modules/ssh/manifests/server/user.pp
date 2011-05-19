class ssh::server::user {

  user { "sshd":
    home => $operatingsystem ? {
      default  => "/var/empty/sshd",
      "Ubuntu" => "/var/run/sshd"
    },
    shell => $operatingsystem ? {
      default  => "/sbin/nologin",
      "Ubuntu" => "/usr/sbin/nologin"
    },
    allowdupe => false,
  }
}
