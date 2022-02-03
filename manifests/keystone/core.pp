# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::keystone::core
class openstack::keystone::core (
  Openstack::Release
          $cycle     = $openstack::cycle,
)
{
  # Identities
  group { 'keystone':
    ensure => present,
    system => true,
  }

  user { 'keystone':
    ensure     => present,
    system     => true,
    gid        => 'keystone',
    comment    => 'OpenStack Keystone Daemons',
    home       => '/var/lib/keystone',
    managehome => true,
    shell      => '/sbin/nologin',
    require    => Group['keystone'],
  }

  file { ['/var/lib/keystone', '/var/log/keystone']:
    ensure  => directory,
    owner   => 'keystone',
    group   => 'keystone',
    mode    => '0711',
    require => User['keystone'],
  }

  openstack::package { 'openstack-keystone':
    cycle   => $cycle,
    configs => [
      '/etc/keystone/keystone.conf',
    ],
    notifyconfigs => false,
  }
}
