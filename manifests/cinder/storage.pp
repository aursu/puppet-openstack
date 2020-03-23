# @summary Block Storage service settings for starage node
#
# Block Storage service settings for starage node
#
# @example
#   include openstack::cinder::storage
class openstack::cinder::storage (
  String  $volume_group       = $openstack::cinder_volume_group,
  Optional[Array[String, 1]]
          $lvm_devices_filter = $openstack::lvm_devices_filter,
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

  package {
    default:
      ensure => present,
    ;
    'lvm2': ;
    'device-mapper-persistent-data': ;
    'targetcli': ;
    'python-keystone': ;
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
      'lvm/iscsi_protocol'         => 'iscsi',
      'lvm/iscsi_helper'           => 'lioadm',
      # [DEFAULT]
      # enabled_backends = lvm
      'DEFAULT/enabled_backends'   => 'lvm',
      # [DEFAULT]
      # glance_api_servers = http://controller:9292
      'DEFAULT/glance_api_servers' => 'http://controller:9292',
    },
    notify  => Service['openstack-cinder-volume'],
    require => Openstack::Config['/etc/cinder/cinder.conf'],
  }

  service {
    default:
      ensure => running,
      enable => true,
    ;
    'openstack-cinder-volume':
      subscribe => Openstack::Config['/etc/cinder/cinder.conf'],
      require   => File['/var/lib/cinder'],
    ;
    'lvm2-lvmetad':
      require => Package['lvm2'],
    ;
    'target':
      require => Package['targetcli'],
    ;
  }
}
