# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::users
class openstack::controller::users {

  # https://docs.openstack.org/keystone/latest/admin/service-api-protection.html
  openstack_role {
    'admin': ;
    'member': ;
    'reader': ;
  }

  openstack::project { 'service':
    selfservice_network => false,
    description         => 'Service Project',
  }
}
