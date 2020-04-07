# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::networking
class openstack::controller::networking (
  String  $provider_physical_network = $openstack::provider_physical_network,
  Stdlib::IP::Address
          $provider_network_cidr     = $openstack::provider_network_cidr,
  Stdlib::IP::Address
          $provider_network_gateway  = $openstack::provider_network_gateway,
  Array[Stdlib::IP::Address]
          $provider_network_dns      = $openstack::provider_network_dns,
  Optional[Stdlib::IP::Address]
          $provider_network_start_ip = $openstack::provider_network_start_ip,
  Optional[Stdlib::IP::Address]
          $provider_network_end_ip   = $openstack::provider_network_end_ip,

){
  openstack_network { $provider_physical_network:
    ensure                    => present,
    shared                    => true,
    external                  => true,
    provider_network_type     => 'flat',
    provider_physical_network => $provider_physical_network,
  }

  openstack_subnet { $provider_physical_network:
    network               => $provider_physical_network,
    subnet_range          => $provider_network_cidr,
    gateway               => $provider_network_gateway,
    allocation_pool_start => $provider_network_start_ip,
    allocation_pool_end   => $provider_network_end_ip,
    dns_nameserver        => $provider_network_dns,
  }
}
