# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::user { 'namevar': }
define openstack::user (
  String  $project,
  String  $user_pass,
  String  $admin_pass,
  Enum['reader', 'member', 'admin']
          $role           = 'member',
  Enum['present', 'absent']
          $ensure         = 'present',
  Optional[String]
          $description    = undef,

  # following instructions from https://docs.openstack.org/glance/train/install/install-rdo.html
  String  $project_domain = 'default',
)
{
  $defined_description = $description ? {
    String  => $description,
    default => "OpenStack ${name} user",
  }

  openstack_user { $name:
    ensure      => present,
    domain      => $project_domain,
    description => $defined_description,
    password    => $user_pass,
  }

  openstack_user_role { "${name}/${role}":
    project => $project,
  }
}
