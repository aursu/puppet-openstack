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
) {
  # https://docs.openstack.org/nova/train/install/compute-install-rdo.html
  include openstack::nova::core
  include openstack::params
  $nova_compute_package = $openstack::params::nova_compute_package
  $nova_compute_service = $openstack::params::nova_compute_service

  # Enable KVM-based Nested Virtualization
  include openstack::compute::nested_virtualization

  if $facts['os']['family'] == 'Debian' {
    $enabled_apis = {}
  }
  else {
    $enabled_apis = {
      'DEFAULT/enabled_apis' => 'osapi_compute,metadata',
    }

    service { 'libvirtd':
        ensure    => running,
        enable    => true,
        subscribe => Openstack::Config['/etc/nova/nova.conf'],
    }
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

  openstack::config { '/etc/nova/nova.conf/compute':
    path    => '/etc/nova/nova.conf',
    content => $conf_default + $virt_type + $enabled_apis,
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

  Openstack::Package[$nova_compute_package] -> Openstack::Config['/etc/nova/nova.conf']
  File['/var/lib/nova'] -> Service[$nova_compute_service]
}
