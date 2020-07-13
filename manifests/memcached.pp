# @summary Install python binding package for Memcached
#
# Install python binding package for Memcached
#
# @example
#   include openstack::memcached
class openstack::memcached {
  if $::osfamily == 'RedHat' {
    # https://docs.openstack.org/install-guide/environment-memcached-rdo.html
    if $facts['os']['release']['major'] == '8' {
      package { 'python3-memcached':
        ensure  => 'present',
      }
    }
    else {
      # https://docs.openstack.org/install-guide/environment-memcached-rdo.html
      package { 'python-memcached':
        ensure  => 'present',
      }
    }
  }
  elsif $::operatingsystem == 'Ubuntu' {
    # https://docs.openstack.org/install-guide/environment-memcached-ubuntu.html
    package { 'python-memcache':
      ensure  => 'present',
    }
  }
}
