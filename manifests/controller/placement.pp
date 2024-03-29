# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::placement
class openstack::controller::placement (
  Openstack::Release
          $cycle            = $openstack::cycle,
  String  $placement_pass   = $openstack::placement_pass,
  String  $placement_dbname = $openstack::placement_dbname,
  String  $placement_dbuser = $openstack::placement_dbuser,
  String  $placement_dbpass = $openstack::placement_dbpass,
  String  $database_tag     = $openstack::database_tag,
  String  $admin_pass       = $openstack::admin_pass,
  Stdlib::Host
          $memcached_host = $openstack::memcached_host,
  Integer $memcached_port = $openstack::memcached_port,
)
{
  include openstack::placement::core
  $placement_package = $openstack::placement::core::placement_package

  # https://docs.openstack.org/placement/train/install/install-rdo.html
  # Verify Installation: https://docs.openstack.org/placement/train/install/verify.html
  openstack::database { $placement_dbname:
    dbuser       => $placement_dbuser,
    dbpass       => $placement_dbpass,
    database_tag => $database_tag,
  }

  openstack::user { 'placement':
    role      => 'admin',
    project   => 'service',
    user_pass => $placement_pass,
    require   => Openstack::Project['service'],
  }

  openstack::service { 'placement':
    service     => 'placement',
    description => 'Placement API',
    endpoint    => {
      public   => 'http://controller:8778',
      internal => 'http://controller:8778',
      admin    => 'http://controller:8778',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['placement'],
  }

  $conf_default = {
    # [placement_database]
    # # ...
    # connection = mysql+pymysql://placement:PLACEMENT_DBPASS@controller/placement
    'placement_database/connection'          => "mysql+pymysql://${placement_dbuser}:${placement_dbpass}@controller/${placement_dbname}",
    # [api]
    # # ...
    # auth_strategy = keystone
    'api/auth_strategy'                      => 'keystone',
    # [keystone_authtoken]
    # # ...
    # auth_url = http://controller:5000/v3
    # memcached_servers = controller:11211
    # auth_type = password
    # project_domain_name = Default
    # user_domain_name = Default
    # project_name = service
    # username = placement
    # password = PLACEMENT_PASS
    'keystone_authtoken/auth_url'            => 'http://controller:5000/v3',
    'keystone_authtoken/memcached_servers'   => "${memcached_host}:${memcached_port}",
    'keystone_authtoken/auth_type'           => 'password',
    'keystone_authtoken/project_domain_name' => 'Default',
    'keystone_authtoken/user_domain_name'    => 'Default',
    'keystone_authtoken/project_name'        => 'service',
    'keystone_authtoken/username'            => 'placement',
    'keystone_authtoken/password'            => $placement_pass,
  }

  exec { 'placement-db-sync':
    command     => 'placement-manage db sync',
    path        => '/bin:/sbin:/usr/bin:/usr/sbin',
    cwd         => '/var/lib/placement',
    user        => 'placement',
    refreshonly => true,
    require     => [
      File['/var/lib/placement'],
      Openstack::Service['placement'],
    ],
  }

  openstack::config { '/etc/placement/placement.conf':
    content => $conf_default,
    require => Openstack::Package[$placement_package],
    notify  => Exec['placement-db-sync'],
  }

  Mysql_database <| title == $placement_dbname |> ~> Exec['placement-db-sync']
}
