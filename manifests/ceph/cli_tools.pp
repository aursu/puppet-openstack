# @summary Ceph client command line tools
#
# Ceph client command line tools
#
# @example
#   include openstack::ceph::cli_tools
class openstack::ceph::cli_tools (
  Boolean $manage_epel_repo = true,
  Boolean $manage_python3   = true,
  Boolean $manage_podman    = true,
)
{
  include openstack::repos::ceph

  if $manage_podman {
    include openstack::repos::podman

    package { 'podman':
      ensure  => present,
      before  => Package['cephadm'],
      require => Class['openstack::repos::podman']
    }
  }

  if $facts['os']['family'] == 'RedHat' {
    if $manage_epel_repo {
      package { 'epel-release':
        ensure => present,
        before => Package['cephadm'],
      }
    }
  }

  if $manage_python3 {
    package { 'python3':
      ensure => present,
      before => Package['cephadm'],
    }
  }

  package {
    default:
      ensure  => present,
      require => Class['openstack::repos::ceph'],
    ;
    'cephadm': ;
    'ceph-common': ;
  }

  # https://docs.ceph.com/en/latest/install/get-packages/
  $cephadm_home = $facts['os']['family'] ? {
    'Debian' => '/home/cephadm',
    default  => '/var/lib/cephadm',
  }

  group { 'cephadm':
    ensure => present,
    system => true,
  }

  user { 'cephadm':
    ensure  => present,
    system  => true,
    gid     => 'cephadm',
    comment => 'cephadm user for mgr/cephadm',
    home    => $cephadm_home,
    shell   => '/bin/bash',
    require => Group['cephadm']
  }

  file {
    default:
      owner   => 'cephadm',
      group   => 'cephadm',
      require => User['cephadm'],
    ;
    [$cephadm_home, "${cephadm_home}/.ssh"]:
      ensure => directory,
      mode   => '0700',
    ;
    "${cephadm_home}/.ssh/authorized_keys":
      ensure => file,
      mode   => '0600',
    ;
  }
}
