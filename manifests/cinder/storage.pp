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
    $lvm_target_helper  = 'lioadm'
    $lvm_target_service = 'tgt'
    $cinder_volume_service = 'cinder-volume'

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
  }
  else {
    $lvm_target_helper = 'tgtadm'
    $lvm_target_service = 'target'
    $cinder_volume_service = 'openstack-cinder-volume'

    package {
      default:
        ensure => present,
      ;
      'device-mapper-persistent-data': ;
      'targetcli':
        before => Service[$lvm_target_service],
      ;
    }

    if $facts['os']['release']['major'] in ['7'] {
      service { 'lvm2-lvmetad':
        require => Package['lvm2'],
      }
    }
  }

  # [cinder]
  # os_region_name = RegionOne
  openstack::config { '/etc/cinder/cinder.conf/storage':
    path    => '/etc/cinder/cinder.conf',
    content => {
      # [lvm]
      # volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
      # volume_group = cinder-volumes
      # target_protocol = iscsi
      # target_helper = lioadm
      'lvm/volume_driver'          => 'cinder.volume.drivers.lvm.LVMVolumeDriver',
      'lvm/volume_group'           => $volume_group,
      'lvm/target_protocol'        => 'iscsi',
      'lvm/target_helper'          => $lvm_target_helper,
      # [DEFAULT]
      # enabled_backends = lvm
      'DEFAULT/enabled_backends'   => 'lvm',
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
}
