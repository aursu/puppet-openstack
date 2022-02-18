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
}
