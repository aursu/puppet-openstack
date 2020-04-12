# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::users
class openstack::controller::users (
  String  $admin_pass = $openstack::admin_pass,
) {
  openstack::project { 'service':
    selfservice_network => false,
    description         => 'Service Project',
  }
}
