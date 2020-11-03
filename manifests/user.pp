# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::user { 'namevar': }
define openstack::user (
  String  $user_pass,
  Enum['present', 'absent']
          $ensure         = 'present',
  Enum['reader', 'member', 'admin']
          $role           = 'member',
  Optional[String]
          $description    = undef,
  String  $user_domain    = 'default',

  # following instructions from https://docs.openstack.org/glance/train/install/install-rdo.html
  Optional[String]
          $project        = undef,
  String  $project_domain = 'default',

  Optional[String]
          $domain         = undef,

  Boolean $setup_openrc   = false,
  Boolean $stack_mgmt     = false,
  Openstack::Release
          $cycle          = $openstack::cycle,
)
{
  $defined_description = $description ? {
    String  => $description,
    default => "OpenStack ${name} user",
  }

  $openstack_user_name = $user_domain ? {
    'default' => $name,
    default   => "${user_domain}/${name}"
  }
  $openstack_user_role_name = "${openstack_user_name}/${role}"

  openstack_user { $openstack_user_name:
    ensure      => $ensure,
    domain      => $user_domain,
    description => $defined_description,
    password    => $user_pass,
  }

  # openstack role add
  # --system <system> | --domain <domain> | --project <project> [--project-domain <project-domain>]
  # --user <user> [--user-domain <user-domain>] | --group <group> [--group-domain <group-domain>]
  # --role-domain <role-domain>
  # --inherited
  # <role>
  if $project {
    openstack_user_role { $openstack_user_role_name:
      ensure         => $ensure,
      project        => $project,
      project_domain => $project_domain,
      user_domain    => $user_domain,
    }

    if $stack_mgmt {
      # Add the heat_stack_owner role to the project and user to enable stack management by the user
      openstack_user_role { "${openstack_user_name}/heat_stack_owner":
        ensure         => $ensure,
        project        => $project,
        project_domain => $project_domain,
        user_domain    => $user_domain,
      }
    }
  }
  elsif $domain {
    openstack_user_role { $openstack_user_role_name:
      ensure      => $ensure,
      domain      => $domain,
      user_domain => $user_domain,
    }
  }

  if $setup_openrc {
    $real_user_pass = shell_escape($user_pass)

    if openstack::cyclecmp($cycle, 'queens') < 0 {
      $os_auth_url = 'http://controller:35357/v3'
    }
    else {
      $os_auth_url = 'http://controller:5000/v3'
    }

    openstack::envscript { "/etc/keystone/${name}-openrc.sh":
      content => {
        'OS_PROJECT_DOMAIN_NAME'  => 'Default',
        'OS_USER_DOMAIN_NAME'     => 'Default',
        'OS_PROJECT_NAME'         => $project,
        'OS_USERNAME'             => $name,
        'OS_PASSWORD'             => $real_user_pass,
        'OS_AUTH_URL'             => $os_auth_url,
        'OS_IDENTITY_API_VERSION' => '3',
        'OS_IMAGE_API_VERSION'    => '2',
        'OS_VOLUME_API_VERSION'   => '3',
      },
    }
  }
}
