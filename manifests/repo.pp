# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::repo
class openstack::repo {
  exec { 'yum-reload-c01e6ce':
    command     => 'yum clean all',
    path        => '/bin:/usr/bin',
    refreshonly => true,
  }
}
