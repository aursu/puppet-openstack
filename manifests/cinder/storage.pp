# @summary Block Storage service settings for starage node
#
# Block Storage service settings for starage node
#
# @example
#   include openstack::cinder::storage
class openstack::cinder::storage (
  Openstack::Release
          $cycle              = $openstack::cycle,
  String  $volume_group       = $openstack::cinder_volume_group,
  Optional[Array[String, 1]]
          $lvm_devices_filter = $openstack::lvm_devices_filter,
  Optional[Array[Stdlib::Unixpath, 1]]
          $physical_volumes   = $openstack::cinder_physical_volumes,
  Boolean $ceph_storage       = $openstack::ceph_storage,
  Boolean $backup_service     = $openstack::cinder_backup_service,
){
  include openstack::cinder::core

  if $lvm_devices_filter {
    $filter = $lvm_devices_filter.reduce('') |$memo, $device| { "${memo} \"a|${device}|\"," }
    openstack::config { '/etc/lvm/lvm.conf':
      content => {
        'devices/filter' => {
          value          => "[${filter} \"r|.*|\" ]",
          section_prefix => '',
          section_suffix => ' {',
          indent_char    => "\t",
        }
      },
    }
  }

  if  $physical_volumes {
    $physical_volumes.each | String $pv | {
      physical_volume { $pv:
        ensure => present,
      }
    }

    volume_group { $volume_group:
      ensure           => present,
      physical_volumes => $physical_volumes,
    }
  }

  package { 'lvm2':
    ensure => present,
  }

  if $facts['os']['family'] == 'Debian' {
    $lvm_target_helper  = 'tgtadm'
    $lvm_target_service = 'tgt'
    $cinder_volume_service = 'cinder-volume'
    $cinder_backup_service = 'cinder-backup'

    package {
      default:
        ensure => present,
      ;
      'thin-provisioning-tools': ;
      'tgt':
        before => Service[$lvm_target_service],
      ;
    }

    openstack::package { 'cinder-volume':
      cycle   => $cycle,
      require => Openstack::Package['cinder-common'],
    }

    if $backup_service {
      openstack::package { 'cinder-backup':
        cycle   => $cycle,
        require => Openstack::Package['cinder-common'],
      }
    }
  }
  else {
    $lvm_target_helper = 'lioadm'
    $lvm_target_service = 'target'
    $cinder_volume_service = 'openstack-cinder-volume'
    $cinder_backup_service = 'openstack-cinder-backup'

    package {
      default:
        ensure => present,
      ;
      'device-mapper-persistent-data': ;
      'targetcli':
        before => Service[$lvm_target_service],
      ;
      'libguestfs-tools': ;
    }

    if $facts['os']['release']['major'] in ['7'] {
      service { 'lvm2-lvmetad':
        require => Package['lvm2'],
      }
    }
  }

  if $ceph_storage {
    $conf_default = {
      # [DEFAULT]
      # enabled_backends = lvm
      # glance_api_version = 2
      'DEFAULT/enabled_backends'   => 'lvm',
      'DEFAULT/glance_api_version' => 2,
      # [ceph]
      # volume_driver = cinder.volume.drivers.rbd.RBDDriver
      # volume_backend_name = ceph
      # rbd_pool = volumes
      # rbd_ceph_conf = /etc/ceph/ceph.conf
      # rbd_flatten_volume_from_snapshot = false
      # rbd_max_clone_depth = 5
      # rbd_store_chunk_size = 4
      # rados_connect_timeout = -1
      'ceph/volume_driver'                    => 'cinder.volume.drivers.rbd.RBDDriver',
      'ceph/volume_backend_name'              => 'ceph',
      'ceph/rbd_pool'                         => 'volumes',
      'ceph/rbd_ceph_conf'                    => '/etc/ceph/ceph.conf',
      'ceph/rbd_flatten_volume_from_snapshot' => 'false',
      'ceph/rbd_max_clone_depth'              => 5,
      'ceph/rbd_store_chunk_size'             => 4,
      'ceph/rados_connect_timeout'            => -1,
    }

    if $backup_service {
      # https://docs.ceph.com/en/latest/rbd/rbd-openstack/#configuring-cinder-backup
      # [DEFAULT]
      # backup_driver = cinder.backup.drivers.ceph
      # backup_ceph_conf = /etc/ceph/ceph.conf
      # backup_ceph_user = cinder-backup
      # backup_ceph_chunk_size = 134217728
      # backup_ceph_pool = backups
      # backup_ceph_stripe_unit = 0
      # backup_ceph_stripe_count = 0
      # restore_discard_excess_bytes = true
      openstack::config { '/etc/cinder/cinder.conf/backup':
        path    => '/etc/cinder/cinder.conf',
        content => {
          'DEFAULT/backup_driver'                => 'cinder.backup.drivers.ceph',
          'DEFAULT/backup_ceph_conf'             => '/etc/ceph/ceph.conf',
          'DEFAULT/backup_ceph_user'             => 'cinder-backup',
          'DEFAULT/backup_ceph_chunk_size'       => 134217728,
          'DEFAULT/backup_ceph_pool'             => 'backups',
          'DEFAULT/backup_ceph_stripe_unit'      => 0,
          'DEFAULT/backup_ceph_stripe_count'     => 0,
          'DEFAULT/restore_discard_excess_bytes' => 'true',
        },
        notify  => [
          Service[$cinder_volume_service],
          Service[$cinder_backup_service],
        ],
        require => Openstack::Config['/etc/cinder/cinder.conf'],
      }

      # Install and configure the backup service
      # https://docs.openstack.org/cinder/latest/install/cinder-backup-install-rdo.html
      service { $cinder_backup_service:
        ensure => running,
        enable => true,
      }
    }
  }
  else {
    $conf_default = {
      # [DEFAULT]
      # enabled_backends = ceph
      'DEFAULT/enabled_backends'   => 'ceph',
      # [lvm]
      # volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
      # volume_group = cinder-volumes
      # target_protocol = iscsi
      # target_helper = lioadm
      'lvm/volume_driver'          => 'cinder.volume.drivers.lvm.LVMVolumeDriver',
      'lvm/volume_group'           => $volume_group,
      'lvm/target_protocol'        => 'iscsi',
      'lvm/target_helper'          => $lvm_target_helper,
    }
  }

  # [cinder]
  # os_region_name = RegionOne
  openstack::config { '/etc/cinder/cinder.conf/storage':
    path    => '/etc/cinder/cinder.conf',
    content => $conf_default + {
      # [DEFAULT]
      # glance_api_servers = http://controller:9292
      'DEFAULT/glance_api_servers' => 'http://controller:9292',
      # debug
      'DEFAULT/debug'              => 'false',
    },
    notify  => Service[$cinder_volume_service],
    require => Openstack::Config['/etc/cinder/cinder.conf'],
  }

  service {
    default:
      ensure => running,
      enable => true,
    ;
    $cinder_volume_service:
      subscribe => Openstack::Config['/etc/cinder/cinder.conf'],
      require   => File['/var/lib/cinder'],
    ;
    $lvm_target_service: ;
  }

  # On the nova-compute, cinder-backup and on the cinder-volume node, use both
  # the Python bindings and the client command line tools
  if $ceph_storage {
    include openstack::ceph::bindings
    include openstack::ceph::cli_tools
    include openstack::ceph::cinder_client
  }
}
