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

  file { '/var/log/keystone/keystone-manage.log':
    owner => 'keystone',
    group => 'keystone',
    mode  => '0644',
  }

  if $facts['os']['family'] == 'Debian' {
    # https://docs.openstack.org/keystone/xena/install/keystone-install-ubuntu.html
    $keystone_package = 'keystone'

    file { '/etc/apache2/sites-available/keystone.conf':
      ensure  => file,
      content => '',
      before  => Openstack::Package[$keystone_package],
    }
  }
  else {
    $keystone_package = 'openstack-keystone'
  }

  if openstack::cyclecmp($cycle, 'xena') < 0 {
    if $facts['os']['family'] == 'RedHat' and $facts['os']['release']['major'] == '7' {
      $python_keystone = 'python-keystone'
    }
    else {
      $python_keystone = 'python3-keystone'
    }

    openstack::package { $python_keystone:
      cycle => $cycle,
    }
  }

  openstack::package { $keystone_package:
    cycle         => $cycle,
    configs       => [
      '/etc/keystone/keystone.conf',
    ],
    notifyconfigs => false,
  }
}
