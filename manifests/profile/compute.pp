# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::profile::compute
class openstack::profile::compute {
  include openstack
  include openstack::install

  include openstack::compute::nova
  include openstack::compute::neutron
  include openstack::cinder::storage
}
