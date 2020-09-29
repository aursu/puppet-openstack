# @summary Enable KVM-based Nested Virtualization
#
# Enable KVM-based Nested Virtualization
# see https://docs.openstack.org/devstack/latest/guides/devstack-with-nested-kvm.html
#
# @example
#   include openstack::compute::nested_virtualization
class openstack::compute::nested_virtualization (
  Boolean $enable              = $openstack::nested_virtualization,
  Boolean $manage_kmod_package = $openstack::manage_kmod_package,
){
  if $manage_kmod_package {
    package { 'kmod':
      ensure => present,
    }
  }

  $nested_should = $enable
  $virt_type     = $facts['virtualization_support']
  $nested_is     = $facts['nested_virtualization']

  $kmod  = $virt_type ? {
    'vmx'   => 'kvm-intel',
    'svm'   => 'kvm-amd',
    default => undef,
  }

  file { 'kvm.conf':
    ensure  => file,
    path    => '/etc/modprobe.d/kvm.conf',
    content => template('openstack/modprobe.d/kvm.conf.erb'),
  }

  $kmod_reload = ($nested_should != $nested_is)

  if $kmod_reload {
    exec { 'rmmod-kvm':
      command => "rmmod ${kmod}",
      path    => '/usr/sbin:/sbin',
      notify  => File['kvm.conf'],
      # we can not remove it if in use
      returns => [0, 1],
    }

    exec { 'modprobe-kvm':
      command     => "modprobe ${kmod}",
      path        => '/usr/sbin:/sbin',
      refreshonly => true,
      subscribe   => Exec['rmmod-kvm'],
      require     => File['kvm.conf']
    }

    if $manage_kmod_package {
      Package['kmod'] -> [
        Exec['rmmod-kvm'],
        Exec['modprobe-kvm']
      ]
    }
  }
}
