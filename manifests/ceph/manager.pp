# @summary Resources to apply on Ceph admin node
#
# Resources to apply on Ceph admin node
#
# @example
#   include openstack::ceph::manager
class openstack::ceph::manager (
  String  $rbd_secret_uuid = $openstack::rbd_secret_uuid,
)
{

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

  if $facts['ceph_conf'] {
    @@file { '/etc/ceph/ceph-exported.conf':
      ensure  => file,
      content => epp('openstack/ceph-conf.epp', {
        global => $facts['ceph_conf']['global'],
        client => $facts['ceph_conf']['client'],
      }),
    }
  }

  if $facts['ceph_client_glance'] {
    @@file { '/etc/ceph/ceph.client.glance.keyring':
      ensure  => file,
      owner   => 'glance',
      group   => 'glance',
      content => $facts['ceph_client_glance'],
    }
  }

  if $facts['ceph_client_cinder'] {
    @@file { '/etc/ceph/ceph.client.cinder.keyring':
      ensure  => file,
      owner   => 'cinder',
      group   => 'cinder',
      content => epp('openstack/keyring.epp', $facts['ceph_client_cinder']),
    }

    @@file { '/etc/ceph/ceph.client.cinder.key':
      ensure  => file,
      owner   => 'cinder',
      group   => 'cinder',
      content => $facts['ceph_client_cinder_key'],
    }

    @@file { '/etc/ceph/client.cinder.secret.xml':
      ensure  => file,
      content => epp('openstack/libvirt-secret.epp', {
        rbd_secret_uuid => $rbd_secret_uuid,
      }),
    }
  }

  if $facts['ceph_client_cinder_backup'] {
    @@file { '/etc/ceph/ceph.client.cinder-backup.keyring':
      ensure  => file,
      owner   => 'cinder',
      group   => 'cinder',
      content => $facts['ceph_client_cinder_backup'],
    }
  }
}
