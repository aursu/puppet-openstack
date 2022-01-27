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

  openstack::package { 'openstack-placement-api':
    cycle   => $cycle,
    configs => [
      '/etc/placement/placement.conf',
    ],
    notify  => Class['Apache::Service'],
  }

  # OpenStack Placement plugin
  if $facts['os']['name'] in ['RedHat', 'CentOS'] {
    case $facts['os']['release']['major'] {
      '7': {
        package { 'python2-osc-placement':
          ensure => 'installed',
        }
      }
      default: {
          package { 'python3-osc-placement':
            ensure => 'installed',
          }
      }
    }
  }
}
