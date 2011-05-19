class ssh::server {
  include ssh::server::user
  include ssh::server::install
  include ssh::server::config
  include ssh::server::service
  include ssh::server::keys
}
