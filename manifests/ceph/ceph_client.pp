# @summary Setup ceph config
#
# Setup Ceph config exported by Ceph manager host
#
# @example
#   include openstack::ceph::ceph_client
class openstack::ceph::ceph_client {
  file { ['/etc/ceph', '/root/ceph']:
    ensure => directory,
  }

  file { '/var/run/ceph':
    ensure => directory,
  }

  File <<| title == '/root/ceph/ceph.conf' |>>
  File <<| title == '/root/ceph/ceph.pub' |>>
}
