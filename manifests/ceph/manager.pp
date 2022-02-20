# @summary Resources to apply on Ceph admin node
#
# Resources to apply on Ceph admin node
#
# @example
#   include openstack::ceph::manager
class openstack::ceph::manager {

  # https://docs.ceph.com/en/latest/rbd/rbd-openstack/#create-a-pool
  # ceph osd pool create volumes
  # ceph osd pool create images
  # ceph osd pool create backups
  # ceph osd pool create vms
  ceph_pool {
    default:
      ensure => present,
      before => Ceph_auth['client.cinder'],
    ;
    'volumes': ;
    'images': ;
    'backups':
      before => Ceph_auth['client.cinder-backup'],
    ;
    'vms': ;
  }

  # /usr/bin/ceph auth get-or-create client.glance \
  #     mon 'profile rbd' \
  #     osd 'profile rbd pool=images' \
  #     mgr 'profile rbd pool=images'
  ceph_auth { 'client.glance':
    ensure  => present,
    cap_mon => 'profile rbd',
    cap_osd => 'profile rbd pool=images',
    cap_mgr => 'profile rbd pool=images',
    require => Ceph_pool['images'],
  }

  # /usr/bin/ceph auth get-or-create client.cinder \
  #     mon 'profile rbd' \
  #     osd 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd-read-only pool=images' \
  #     mgr 'profile rbd pool=volumes, profile rbd pool=vms'
  ceph_auth { 'client.cinder':
    ensure  => present,
    cap_mon => 'profile rbd',
    cap_osd => 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd-read-only pool=images',
    cap_mgr => 'profile rbd pool=volumes, profile rbd pool=vms',
  }

  # /usr/bin/ceph auth get-or-create client.cinder-backup \
  #     mon 'profile rbd' \
  #     osd 'profile rbd pool=backups' \
  #     mgr 'profile rbd pool=backups'
  ceph_auth { 'client.cinder-backup':
    ensure  => present,
    cap_mon => 'profile rbd',
    cap_osd => 'profile rbd pool=backups',
    cap_mgr => 'profile rbd pool=backups',
  }

  if $facts['ceph_client_glance'] {
    @@file { '/etc/ceph/ceph.client.glance.keyring':
      ensure  => file,
      content => $facts['ceph_client_glance'],
    }
  }
}