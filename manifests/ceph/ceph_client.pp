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

  # if not Ceph admin host
  unless $facts['ceph_conf'] {
    File <<| title == '/etc/ceph/ceph.conf' |>>
  }
}
