# @summary Run OpenStack command
#
# Resource which control interraction with OpenStack CLI tools
#
# @example
#   openstack::command { 'openstack-project-service':
#     command => 'openstack project create --domain default --description OpenStack\ service\ project service',
#   }
define openstack::command (
  String  $admin_pass,
  String  $command,
  String  $exec_title     = $name,
  Optional[String]
          $unless         = undef,
  Enum['present', 'absent']
          $ensure         = 'present',
  String  $os_username    = 'admin',
  String  $os_project     = 'admin',
  String  $project_domain = 'Default',
  String  $user_domain    = 'Default',
  Enum['http', 'https']
          $auth_schema    = 'http',
  String  $auth_host      = 'controller',
  Integer $auth_port      = 5000,
  Integer $api_version    = 3,
  Array[String]
          $env_override   = [],
)
{
  $auth_url = "${auth_schema}://${auth_host}:${auth_port}/v3"

  $env = [
    "OS_PROJECT_DOMAIN_NAME=${project_domain}",
    "OS_USER_DOMAIN_NAME=${user_domain}",
    "OS_PROJECT_NAME=${os_project}",
    "OS_USERNAME=${os_username}",
    "OS_PASSWORD=${admin_pass}",
    "OS_AUTH_URL=${auth_url}",
    "OS_IDENTITY_API_VERSION=${api_version}",
    'OS_IMAGE_API_VERSION=2',
  ] + $env_override

  exec { $exec_title:
    command     => $command,
    path        => '/bin:/sbin:/usr/bin:/usr/sbin',
    unless      => $unless,
    environment => $env,
    require     => Package['openstack-keystone'],
  }

  if defined(Class['Apache::Service']) {
    Class['Apache::Service'] -> Exec[$exec_title]
  }
}
