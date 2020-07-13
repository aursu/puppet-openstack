# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::install
class openstack::install (
  Openstack::Release $cycle = $openstack::cycle,
){
  openstack::repository { $cycle: }

  if $facts['os']['family'] == 'RedHat' and $facts['os']['release']['major'] == '8' {
    yumrepo { 'PowerTools':
      enabled => true,
    }

    $openstackclient = 'python3-openstackclient'
  }
  else {
    $openstackclient = 'python-openstackclient'
  }

  # https://docs.openstack.org/install-guide/environment-packages-rdo.html#finalize-the-installation
  package {
    default:
      ensure  => 'present',
      require => Openstack::Repository[$cycle],
    ;
    $openstackclient:
    ;
    'openstack-selinux':
    ;
  }
}
