class ssh::server::keys {
  file {
    "/root/.ssh":
      ensure => directory, mode => 700;
    "/root/.ssh/authorized_keys":
#      source => ["$fileserver/users/.ssh/authorized_keys.$fqdn",
#                 "$fileserver/users/.ssh/authorized_keys"],
      mode => 0400
  }
}
