class ssh::client {
  include ssh::common

  package { "openssh-client":
    name => $operatingsystem ? {
      Ubuntu => "openssh-client",
      default  => "openssh-clients",
    },
  }
}
