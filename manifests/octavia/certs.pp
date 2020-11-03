# @summary Octavia Certificate Configuration
#
# Octavia Certificate Configuration
#
# @example
#   include openstack::octavia::certs
class openstack::octavia::certs {
  include tlsinfo
  include tlsinfo::tools::cfssl

  file { '/etc/octavia/certs':
    ensure => 'directory',
    mode   => '0700',
  }
}
