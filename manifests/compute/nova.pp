# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::compute::nova
class openstack::compute::nova (
  Openstack::Release
          $cycle                     = $openstack::cycle,
  String  $nova_pass                 = $openstack::nova_pass,
  Stdlib::Host
          $controller_host           = $openstack::controller_host,
  String  $compute_tag               = $openstack::compute_tag,
) {
  # https://docs.openstack.org/nova/train/install/compute-install-rdo.html
  include openstack::nova::core

  openstack::package { 'openstack-nova-compute':
    cycle   => $cycle,
    configs => [
      '/etc/nova/nova.conf',
    ],
  }

  $conf_default = {
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
  if $::virtualization_support {
    $virt_type = {
      'libvirt/virt_type' => 'kvm'
    }
  }
  else {
    $virt_type = {
      'libvirt/virt_type' => 'qemu'
    }
  }

  openstack::config { '/etc/nova/nova.conf/compute':
    path    => '/etc/nova/nova.conf',
    content => $conf_default + $virt_type,
    require => Openstack::Config['/etc/nova/nova.conf'],
    notify  => Service['openstack-nova-compute'],
  }

  service {
    default:
      ensure    => running,
      enable    => true,
      subscribe => Openstack::Config['/etc/nova/nova.conf'],
    ;
    'openstack-nova-compute': ;
    'libvirtd': ;
  }

  @@openstack::nova::host { $::hostname:
    tag => $compute_tag,
  }

  Openstack::Package['openstack-nova-compute'] -> Openstack::Config['/etc/nova/nova.conf']
  File['/var/lib/nova'] -> Service['openstack-nova-compute']
}