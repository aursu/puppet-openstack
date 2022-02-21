# @summary Setup ceph config
#
# Setup Ceph config exported by Ceph manager host
#
# @example
#   include openstack::ceph::ceph_client
class openstack::ceph::ceph_client {
  file { '/etc/ceph':
    ensure => directory,
  }

  file { '/var/run/ceph':
    ensure => directory,
  }

  File <<| title == '/etc/ceph/ceph-exported.conf' |>>
}
