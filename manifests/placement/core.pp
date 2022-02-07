# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::placement::core
class openstack::placement::core (
  Openstack::Release
          $cycle = $openstack::cycle,
)
{
  # Identities
  group { 'placement':
    ensure => present,
    system => true,
  }

  user { 'placement':
    ensure     => present,
    system     => true,
    gid        => 'placement',
    comment    => 'OpenStack Placement Daemons',
    home       => '/var/lib/placement',
    shell      => '/sbin/nologin',
    managehome => true,
    require    => Group['placement'],
  }

  file { '/var/lib/placement':
    ensure  => directory,
    owner   => 'placement',
    group   => 'placement',
    mode    => '0711',
    require => User['placement'],
  }

  $placement_package = $facts['os']['name'] ? {
    'Ubuntu' => 'placement-api',
    default  => 'openstack-placement-api',
  }

  openstack::package { $placement_package:
    cycle         => $cycle,
    configs       => [
      '/etc/placement/placement.conf',
    ],
    notifyconfigs => false,
  }

  # OpenStack Placement plugin
  if $facts['os']['family'] == 'RedHat' {
    case $facts['os']['release']['major'] {
      '7': {
        package { 'python2-osc-placement':
          ensure => 'installed',
        }
      }
      default: {
        openstack::package { 'python3-osc-placement':
          cycle => $cycle,
        }
      }
    }
  }
}
