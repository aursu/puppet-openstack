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
) {
  $defined_description = $description ? {
    String  => shell_escape($description),
    default => "OpenStack\\ ${name}\\ user",
  }

  $shell_user_pass = shell_escape($user_pass)

  if $ensure == 'present' {
    openstack::command { "openstack-user-${name}":
      admin_pass => $admin_pass,
      command    => "openstack user create --domain ${project_domain} --description ${defined_description} --password ${shell_user_pass} ${name}", # lint:ignore:140chars
      unless     => "openstack user show ${name}",
    }

    openstack::command { "openstack-user-${name}-role":
      admin_pass  => $admin_pass,
      command     => "openstack role add --user ${name} --project ${project} ${role}",
      refreshonly => true,
      subscribe   => Openstack::Command["openstack-user-${name}"],
      require     => Openstack::Project[$project]
    }
  }
}
