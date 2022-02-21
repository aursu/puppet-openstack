# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::compute::nova
class openstack::compute::nova (
  Openstack::Release
          $cycle                 = $openstack::cycle,
  String  $nova_pass             = $openstack::nova_pass,
  Stdlib::Host
          $controller_host       = $openstack::controller_host,
  String  $compute_tag           = $openstack::compute_tag,
  Boolean $nested_virtualization = $openstack::nested_virtualization,
  Boolean $ceph_storage          = $openstack::ceph_storage,
  String  $rbd_secret_uuid       = $openstack::rbd_secret_uuid,
) {
  # https://docs.openstack.org/nova/train/install/compute-install-rdo.html
  include openstack::nova::core
  include openstack::params
  $nova_compute_package = $openstack::params::nova_compute_package
  $nova_compute_service = $openstack::params::nova_compute_service

  # Enable KVM-based Nested Virtualization
  include openstack::compute::nested_virtualization

  if $facts['os']['family'] == 'Debian' {
    $libvirt_clients = 'libvirt-clients'
  }
  else {
    $libvirt_clients = 'libvirt'

    service { 'libvirtd':
        ensure    => running,
        enable    => true,
        subscribe => Openstack::Config['/etc/nova/nova.conf'],
        require   => Package['libvirt'],
        before    => Class['openstack::ceph::ceph_client_nova'],
    }
  }

  package { $libvirt_clients:
    ensure => 'present',
  }

  openstack::package { $nova_compute_package:
    cycle   => $cycle,
    configs => [
      '/etc/nova/nova.conf',
    ],
  }

  $conf_default = {
    'DEFAULT/compute_driver'                  => 'libvirt.LibvirtDriver',
    'DEFAULT/instances_path'                  => '$state_path/instances',
    'DEFAULT/state_path'                      => '/var/lib/nova',
    # logging
    'DEFAULT/log_file'                        => '/var/log/nova/nova-compute.log',
    'DEFAULT/use_journal'                     => 'false',
    ### remote console access
    # [vnc]
    # enabled = true
    # server_listen = 0.0.0.0
    # server_proxyclient_address = $my_ip
    # novncproxy_base_url = http://controller:6080/vnc_auto.html
    'vnc/enabled'                             => 'true',
    'vnc/server_listen'                       => '0.0.0.0',
    'vnc/server_proxyclient_address'          => '$my_ip',
    'vnc/novncproxy_base_url'                 => "http://${controller_host}:6080/vnc_auto.html",
  }

  # check hardware acceleration for virtual machines
  # egrep -c '(vmx|svm)' /proc/cpuinfo
  # [libvirt]
  # virt_type = qemu
  if $facts['virtualization_support'] {
    $nested = $facts['nested_virtualization']
    if $nested_virtualization and $nested {
      $virt_type = {
        'libvirt/virt_type' => 'kvm',
        # Use the host CPU model exactly
        'libvirt/cpu_mode'  => 'host-passthrough',
      }
    }
    else {
      $virt_type = {
        'libvirt/virt_type' => 'kvm',
        'libvirt/cpu_mode'  => {
          ensure => absent,
          value  => 'host-passthrough',
        }
      }
    }
  }
  else {
    $virt_type = {
      'libvirt/virt_type' => 'qemu'
    }
  }

  if $ceph_storage {
    # In order to attach Cinder devices (either normal block or by issuing a
    # boot from volume), you must tell Nova (and libvirt) which user and UUID to
    # refer to when attaching the device. libvirt will refer to this user when
    # connecting and authenticating with the Ceph cluster.
    # expanded following instructions
    # https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/4/html/block_device_to_openstack_guide/configuring-openstack-to-use-ceph-block-devices
    $virt_auth = {
      'libvirt/images_type'          => 'rbd',
      'libvirt/images_rbd_pool'      => 'vms',
      'libvirt/images_rbd_ceph_conf' => '/etc/ceph/ceph.conf',
      'libvirt/rbd_user'             => 'cinder',
      'libvirt/rbd_secret_uuid'      => $rbd_secret_uuid,
      'libvirt/disk_cachemodes'      => 'network=writeback',
      'libvirt/inject_password'      => 'false',
      'libvirt/inject_key'           => 'false',
      'libvirt/inject_partition'     => -2,
      'libvirt/live_migration_flag'  => 'VIR_MIGRATE_UNDEFINE_SOURCE,VIR_MIGRATE_PEER2PEER,VIR_MIGRATE_LIVE,VIR_MIGRATE_PERSIST_DEST,VIR_MIGRATE_TUNNELLED',
      'libvirt/hw_disk_discard'      => 'unmap',
    }
  }
  else  {
    $virt_auth = {}
  }

  openstack::config { '/etc/nova/nova.conf/compute':
    path    => '/etc/nova/nova.conf',
    content => $conf_default +
              $virt_type +
              $virt_auth,
    require => Openstack::Config['/etc/nova/nova.conf'],
    notify  => Service[$nova_compute_service],
  }

  service { $nova_compute_service:
    ensure    => running,
    enable    => true,
    subscribe => Openstack::Config['/etc/nova/nova.conf'],
  }

  @@openstack::nova::host { $::hostname:
    tag => $compute_tag,
  }

  # On the nova-compute, cinder-backup and on the cinder-volume node, use both
  # the Python bindings and the client command line tools
  if $ceph_storage {
    include openstack::ceph::bindings
    include openstack::ceph::cli_tools
    include openstack::ceph::cinder_client
    include openstack::ceph::ceph_client_nova

    Package[$libvirt_clients] -> Class['openstack::ceph::ceph_client_nova']
  }

  Openstack::Package[$nova_compute_package] -> Openstack::Config['/etc/nova/nova.conf']
  File['/var/lib/nova'] -> Service[$nova_compute_service]
}
