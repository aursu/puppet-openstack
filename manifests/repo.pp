# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::repo
class openstack::repo {
  if $facts['os']['name'] == 'Ubuntu' {
    exec { 'apt-update-c01e6ce':
      command     => 'apt update',
      path        => '/bin:/usr/bin',
      refreshonly => true,
    }
  }
  elsif  $facts['os']['name'] == 'CentOS' {
    exec { 'yum-reload-c01e6ce':
      command     => 'yum clean all',
      path        => '/bin:/usr/bin',
      refreshonly => true,
    }
  }
}
