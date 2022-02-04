# @summary Install python binding package for Memcached
#
# Install python binding package for Memcached
#
# @example
#   include openstack::memcached
class openstack::memcached {
  if $facts['os']['family'] == 'RedHat' {
    # https://docs.openstack.org/install-guide/environment-memcached-rdo.html
    $python_client = $facts['os']['release']['major'] ? {
      '7'     => 'python-memcached',
      default => 'python3-memcached',
    }
  }
  elsif $facts['os']['name'] == 'Ubuntu' {
    # https://docs.openstack.org/install-guide/environment-memcached-ubuntu.html
    if versioncmp($facts['os']['release']['major'], '18.04') >= 0 {
      $python_client = 'python3-memcache'
    }
    else {
      $python_client = 'python-memcache'
    }
  }

  package { $python_client:
    ensure  => 'present',
  }
}
