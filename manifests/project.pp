# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::project { 'namevar': }
define openstack::project (
  Enum['present', 'absent']
          $ensure                      = 'present',
  # following instructions from https://docs.openstack.org/keystone/train/install/keystone-users-obs.html
  String  $project_domain              = 'default',
  Optional[String]
          $description                 = undef,
  Boolean $selfservice_network         = true,
  Optional[Stdlib::IP::Address]
          $selfservice_network_cidr    = undef,
  Optional[Stdlib::IP::Address]
          $selfservice_network_gateway = undef,
  Optional[
    Array[Stdlib::IP::Address]
  ]       $selfservice_network_dns     = $openstack::provider_network_dns,
  # name of external network (provider network)
  # https://docs.openstack.org/ocata/install-guide-rdo/launch-instance-networks-selfservice.html
  Optional[String]
          $external_gateway            = $openstack::provider_physical_network,
  Optional[String]
          $external_gateway_subnet    = $openstack::provider_physical_subnet,
  Optional[Stdlib::IP::Address]
          $external_gateway_ip         = undef,
  Boolean $secopen                     = false,
)
{
  $defined_description = $description ? {
    String  => $description,
    default => "OpenStack ${name} project",
  }

  openstack_project { $name:
    ensure                   => $ensure,
    domain                   => $project_domain,
    description              => $defined_description,
    # authentication
    auth_project_domain_name => $project_domain,
  }

  if $selfservice_network {
    # create network
    openstack_network { "${name}-net":
      project => $name,
    }

    # create subnet
    openstack_subnet { "${name}-subnet":
      network        => "${name}-net",
      subnet_range   => $selfservice_network_cidr,
      gateway        => $selfservice_network_gateway,
      dns_nameserver => $selfservice_network_dns,
      project        => $name,
    }

    if $external_gateway_ip and $external_gateway_subnet {
      $external_gateway_info = {
        external_gateway_ip     => $external_gateway_ip,
        external_gateway_subnet => $external_gateway_subnet,
      }
    }
    else {
      $external_gateway_info = {}
    }

    # create router
    openstack_router { "${name}-gw":
      project                  => $name,
      external_gateway_network => $external_gateway,
      subnets                  => [ "${name}-subnet" ],
      *                        => $external_gateway_info,
    }
  }

  if $secopen {
    openstack::net::secopen { $name: }
  }
}
