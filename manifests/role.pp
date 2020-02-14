# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::role { 'admin': }
define openstack::role (
  String  $admin_pass,
  Enum['present', 'absent']
          $ensure = 'present',
)
{
  if $ensure == 'present' {
    openstack::command { "openstack-role-${name}":
      admin_pass => $admin_pass,
      command    => "openstack role create ${name}",
      unless     => "openstack role show ${name}",
    }
  }
}
