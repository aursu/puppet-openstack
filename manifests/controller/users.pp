# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::users
class openstack::controller::users (
  String  $admin_pass = $openstack::admin_pass,
) {
  openstack::role { 'admin':
    admin_pass => $admin_pass,
  }

  openstack::project { 'service':
    selfservice_network => false,
    admin_pass          => $admin_pass,
    description         => 'Service Project',
  }

  openstack::role { 'user':
    admin_pass => $admin_pass,
    require    => Openstack::Project['service'],
  }
}
