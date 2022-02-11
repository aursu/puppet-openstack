# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::params
class openstack::params {
  # Puppet > 6
  if 'distro' in $facts['os'] {
    # centos stream
    $centos_stream = $facts['os']['release']['major'] ? {
      '6' => false,
      '7' => false,
      '9' => true,
      default => $facts['os']['distro']['id'] ? {
        'CentOSStream' => true,
        default        => false,
      },
    }
  }
  else {
    $centos_stream = $facts['os']['release']['full'] ? {
      # for CentOS Stream 8 it is just '8' but for CentOS Linux 8 it is 8.x.x
      '8'     => true,
      '9'     => true,
      default => false,
    }
  }

  if $facts['os']['family'] == 'Debian' {
    $nova_compute_package = 'nova-compute'
    $nova_compute_service = 'nova-compute'
  }
  else {
    $nova_compute_package = 'openstack-nova-compute'
    $nova_compute_service = 'openstack-nova-compute'
  }
}
