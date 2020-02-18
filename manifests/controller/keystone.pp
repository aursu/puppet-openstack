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
  # Identities
  group { 'keystone':
    ensure => present,
    system => true,
  }

  user { 'keystone':
    ensure  => present,
    system  => true,
    gid     => 'keystone',
    comment => 'OpenStack Keystone Daemons',
    home    => '/var/lib/keystone',
    shell   => '/sbin/nologin',
    require => Group['keystone'],
  }

  file { '/var/log/keystone':
    ensure  => directory,
    owner   => 'keystone',
    group   => 'keystone',
    mode    => '0711',
    require => User['keystone'],
  }

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

  openstack::package { 'openstack-keystone':
    cycle   => $cycle,
    configs => [
      '/etc/keystone/keystone.conf',
    ],
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

  exec {
    default:
      path    => '/bin:/sbin:/usr/bin:/usr/sbin',
      cwd     => '/var/lib/keystone',
      require => [
        File['/var/log/keystone'],
        Openstack::Package['openstack-keystone'],
      ],
    ;

    # Populate the Identity service database
    'keystone-db-sync':
      command     => 'keystone-manage db_sync',
      user        => 'keystone',
      refreshonly => true,
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
    require => Openstack::Package['openstack-keystone'],
  }

  Mysql_database <| title == $keystone_dbname |> ~> Exec['keystone-db-sync']
}
