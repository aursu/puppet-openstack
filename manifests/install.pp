# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::install
class openstack::install (
  Openstack::Release $cycle = $openstack::cycle,
){
  include openstack::params

  openstack::repository { $cycle: }

  case $facts['os']['name'] {
    'CentOS': {
      if $facts['os']['release']['major'] == '8' {
        $openstackclient = 'python3-openstackclient'

        if $openstack::params::centos_stream {
          # Network Functions Virtualization (NFV) SIG
          package { 'centos-release-nfv-openvswitch':
            ensure => latest,
            before => Openstack::Repository[$cycle],
          }

          # in case of upgrade from CentOS 8 to CentOS 8 Stream
          file { '/etc/dnf/vars/nfvsigdist':
            ensure  => file,
            content => "8-stream\n",
            before  => Openstack::Repository[$cycle],
          }
        }
      }
      else {
        $openstackclient = 'python-openstackclient'
      }

      package { 'openstack-selinux':
        ensure  => 'present',
        require => Openstack::Repository[$cycle],
      }
    }
    'Ubuntu': {
      $openstackclient = 'python3-openstackclient'
    }
    default: {
      fail("OS is not supported")
    }
  }

  # https://docs.openstack.org/install-guide/environment-packages-rdo.html#finalize-the-installation
  package { $openstackclient:
    ensure  => 'present',
    require => Openstack::Repository[$cycle],
  }
}
