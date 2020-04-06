# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::networking
class openstack::controller::networking (
  String  $provider_physical_network = $openstack::provider_physical_network,
){
  openstack_network { $provider_physical_network:
    ensure                    => present,
    shared                    => true,
    external                  => true,
    provider_network_type     => 'flat',
    provider_physical_network => $provider_physical_network,
  }

}
