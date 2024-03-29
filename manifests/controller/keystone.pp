# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::keystone
class openstack::controller::keystone (
  Openstack::Release
          $cycle           = $openstack::cycle,
  String  $keystone_dbname = $openstack::keystone_dbname,
  String  $keystone_dbuser = $openstack::keystone_dbuser,
  String  $keystone_dbpass = $openstack::keystone_dbpass,
  String  $database_tag    = $openstack::database_tag,
  String  $admin_pass      = $openstack::admin_pass,
)
{
  include openstack::keystone::core
  $keystone_package = $openstack::keystone::core::keystone_package

  openstack::database { $keystone_dbname:
    dbuser       => $keystone_dbuser,
    dbpass       => $keystone_dbpass,
    database_tag => $database_tag,
  }

  openstack::config { '/etc/keystone/keystone.conf':
    content => {
      'database/connection' => "mysql+pymysql://${keystone_dbuser}:${keystone_dbpass}@controller/${keystone_dbname}",
      # configure the Fernet token provider
      'token/provider'      => 'fernet',
    },
    notify  => Exec['keystone-db-sync'],
  }

  # environment files password should be escaped
  $real_admin_pass = shell_escape($admin_pass)

  if openstack::cyclecmp($cycle, 'queens') < 0 {
    $os_auth_url = 'http://controller:35357/v3'
    $bootstrap_command = "keystone-manage bootstrap --bootstrap-password ${real_admin_pass} --bootstrap-admin-url http://controller:35357/v3/ --bootstrap-internal-url http://controller:35357/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne"
  }
  else {
    $os_auth_url = 'http://controller:5000/v3'
    $bootstrap_command = "keystone-manage bootstrap --bootstrap-password ${real_admin_pass} --bootstrap-admin-url http://controller:5000/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne"
  }

  # Populate the Identity service database
  exec { 'keystone-db-sync':
    command     => 'keystone-manage db_sync',
    path        => '/bin:/sbin:/usr/bin:/usr/sbin',
    refreshonly => true,
    user        => 'keystone',
    cwd         => '/var/lib/keystone',
    require     => [
      File['/var/lib/keystone'],
      File['/var/log/keystone/keystone-manage.log'],
      Openstack::Package[$keystone_package],
    ],
  }

  exec {
    default:
      path    => '/bin:/sbin:/usr/bin:/usr/sbin',
      cwd     => '/var/lib/keystone',
      require => Exec['keystone-db-sync'],
    ;

    # setup a fernet key repository for token encryption
    'fernet-token-encryption':
      command => 'keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone',
      creates => '/etc/keystone/fernet-keys/0',
    ;

    # setup a fernet key repository for credential encryption
    'fernet-credential-encryption':
      command => 'keystone-manage credential_setup --keystone-user keystone --keystone-group keystone',
      creates => '/etc/keystone/credential-keys/0',
    ;

    # Bootstrap the Identity service:
    'keystone-manage-bootstrap':
      command     => $bootstrap_command,
      refreshonly => true,
      subscribe   => Exec['keystone-db-sync'],
    ;
  }

  openstack::envscript { '/etc/keystone/admin-openrc.sh':
    content => {
      'OS_PROJECT_DOMAIN_NAME'  => 'Default',
      'OS_USER_DOMAIN_NAME'     => 'Default',
      'OS_PROJECT_NAME'         => 'admin',
      'OS_USERNAME'             => 'admin',
      'OS_PASSWORD'             => $real_admin_pass,
      'OS_AUTH_URL'             => $os_auth_url,
      'OS_IDENTITY_API_VERSION' => '3',
      'OS_IMAGE_API_VERSION'    => '2'
    },
    require => Exec['keystone-manage-bootstrap'],
  }

  Mysql_database <| title == $keystone_dbname |> ~> Exec['keystone-db-sync']
}
