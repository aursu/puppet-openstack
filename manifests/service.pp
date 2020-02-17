# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::service { 'glance': }
define openstack::service (
  Enum[ 'identity', 'image', 'compute', 'placement', 'network', 'volume',
    'volumev2', 'volumev3', 'share', 'sharev2', 'object-store',
    'orchestration', 'cloudformation']
          $service,
  Openstack::Service::Url $endpoint,

  String  $admin_pass,

  Enum['present', 'absent']
          $ensure      = 'present',
  String  $region_id   = 'RegionOne',
  Optional[String]
          $description = undef,
) {
  $defined_description = $description ? {
    String  => shell_escape($description),
    default => "OpenStack\\ ${name}\\ service",
  }

  if $ensure == 'present' {
    openstack::command { "openstack-service-${service}":
      admin_pass => $admin_pass,
      command    => "openstack service create --name ${name} --description ${defined_description} ${service}",
      unless     => "openstack service show ${service}",
    }

    $endpoint.each |$iface, $url| {
      $shell_url = shell_escape($url)

      openstack::command { "endpoint-${service}-${iface}":
        admin_pass => $admin_pass,
        command    => "openstack endpoint create --region ${region_id} ${service} ${iface} ${shell_url}",
        unless     => "openstack endpoint list --interface ${iface} --service ${service} | grep -w ${iface}",
      }
    }
  }
}
