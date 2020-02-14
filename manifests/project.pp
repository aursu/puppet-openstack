# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::project { 'namevar': }
define openstack::project (
  String  $admin_pass,
  Enum['present', 'absent']
          $ensure         = 'present',
  # following instructions from https://docs.openstack.org/keystone/train/install/keystone-users-obs.html
  String  $project_domain = 'default',
  Optional[String]
          $description    = undef,
)
{
  $defined_description = $description ? {
    String  => shell_escape($description),
    default => "OpenStack\\ ${name}\\ project",
  }

  if $ensure == 'present' {
    openstack::command { "openstack-project-${name}":
      admin_pass     => $admin_pass,
      command        => "openstack project create --domain ${project_domain} --description ${defined_description} ${name}",
      unless         => "openstack project show ${name}",
      project_domain => $project_domain,
    }
  }
}
