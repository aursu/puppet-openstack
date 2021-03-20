# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::glance::core
class openstack::glance::core {
  $filesystem_store_datadir = '/var/lib/glance/images'

  # Identities
  group { 'glance':
    ensure => present,
    system => true,
  }

  user { 'glance':
    ensure     => present,
    system     => true,
    gid        => 'glance',
    comment    => 'OpenStack Glance Daemons',
    home       => '/var/lib/glance',
    managehome => true,
    shell      => '/sbin/nologin',
    require    => Group['glance'],
  }

  file {
    default:
      ensure  => directory,
      owner   => 'glance',
      group   => 'glance',
      require => User['glance'],
    ;
    '/var/lib/glance': mode => '0711';
    $filesystem_store_datadir: mode => '0750';
  }
}
