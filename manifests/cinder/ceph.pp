# @summary Ceph installation
#
# Ceph installation
#
# @example
#   include openstack::cinder::ceph
class openstack::cinder::ceph
{
  include openstack::ceph::cli_tools

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
