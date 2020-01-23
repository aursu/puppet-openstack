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

  # https://docs.openstack.org/install-guide/environment-packages-rdo.html#finalize-the-installation
  package {
    default:
      ensure  => 'present',
      require => Openstack::Repository[$cycle],
    ;
    'python-openstackclient':
    ;
    'openstack-selinux':
    ;
  }
}
