# @summary Ceph client command line tools
#
# Ceph client command line tools
#
# @example
#   include openstack::ceph::cli_tools
class openstack::ceph::cli_tools {
  include openstack::repos::ceph

  package { 'ceph-common':
    ensure  => present,
    require => Class['openstack::repos::ceph'],
  }
}
