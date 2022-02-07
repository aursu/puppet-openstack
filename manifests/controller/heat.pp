# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::heat
class openstack::controller::heat (
  Openstack::Release
          $cycle            = $openstack::cycle,
  String  $admin_pass       = $openstack::admin_pass,
  String  $heat_dbname      = $openstack::heat_dbname,
  String  $heat_dbuser      = $openstack::heat_dbuser,
  String  $heat_dbpass      = $openstack::heat_dbpass,
  String  $database_tag     = $openstack::database_tag,
  String  $heat_pass        = $openstack::heat_pass,
  String  $heat_domain_pass = $openstack::heat_domain_pass,
  String  $rabbitmq_user    = $openstack::rabbitmq_user,
  String  $rabbit_pass      = $openstack::rabbit_pass,
  Stdlib::Host
          $memcached_host   = $openstack::memcached_host,
  Integer $memcached_port   = $openstack::memcached_port,
)
{
  # Doc: https://docs.openstack.org/heat/victoria/template_guide/hot_guide.html
  # Doc: https://docs.openstack.org/heat/latest/template_guide/basic_resources.html
  #
  # Manual for Train: https://docs.openstack.org/heat/train/install/install-rdo.html
  openstack::database { $heat_dbname:
    dbuser       => $heat_dbuser,
    dbpass       => $heat_dbpass,
    database_tag => $database_tag,
  }

  openstack::user { 'heat':
    role      => 'admin',
    project   => 'service',
    user_pass => $heat_pass,
    require   => Openstack::Project['service'],
  }

  openstack::service { 'heat':
    service     => 'orchestration',
    description => 'Orchestration',
    endpoint    => {
      public   => 'http://controller:8004/v1/%(tenant_id)s',
      internal => 'http://controller:8004/v1/%(tenant_id)s',
      admin    => 'http://controller:8004/v1/%(tenant_id)s',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['heat'],
  }

  openstack::service { 'heat-cfn':
    service     => 'cloudformation',
    description => 'Orchestration',
    endpoint    => {
      public   => 'http://controller:8000/v1',
      internal => 'http://controller:8000/v1',
      admin    => 'http://controller:8000/v1',
    },
    admin_pass  => $admin_pass,
    require     => [
      Openstack::User['heat'],
      Openstack::Service['heat'],
    ]
  }

  # openstack domain create --description "Stack projects and users" heat
  openstack_domain { 'heat':
    description => 'Stack projects and users',
  }

  # openstack user create --domain heat --password-prompt heat_domain_admin
  # openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
  openstack::user { 'heat_domain_admin':
    user_pass   => $heat_domain_pass,
    role        => 'admin',
    description => 'Stack domain admin',
    user_domain => 'heat',
    domain      => 'heat',
  }

  # openstack role create heat_stack_owner
  openstack_role { 'heat_stack_owner':
    ensure => present,
  }

  # openstack role create heat_stack_user
  openstack_role { 'heat_stack_user':
    ensure => present,
  }

  if $facts['os']['family'] == 'Debian' {
    openstack::package {
      default:
        cycle   => $cycle,
      ;
      'heat-api':
        configs => [
          '/etc/heat/heat.conf',
        ],
      ;
      'heat-api-cfn': ;
      'heat-engine': ;
    }
  }
  else {
    openstack::package {
      default:
        cycle   => $cycle,
      ;
      'openstack-heat-api':
        configs => [
          '/etc/heat/heat.conf',
        ],
      ;
      'openstack-heat-api-cfn': ;
      'openstack-heat-engine': ;
    }
  }

  # Identities
  group { 'heat':
    ensure => present,
    system => true,
  }

  user { 'heat':
    ensure     => present,
    system     => true,
    gid        => 'heat',
    comment    => 'OpenStack Heat',
    home       => '/var/lib/heat',
    managehome => true,
    shell      => '/sbin/nologin',
    require    => Group['heat'],
  }

  file { '/var/lib/heat':
    ensure  => directory,
    owner   => 'heat',
    group   => 'heat',
    mode    => '0711',
    require => User['heat'],
  }

  exec { 'heat-db-sync':
    command     => 'heat-manage db_sync',
    path        => '/bin:/sbin:/usr/bin:/usr/sbin',
    cwd         => '/var/lib/heat',
    user        => 'heat',
    refreshonly => true,
    require     => [
      File['/var/lib/heat'],
      Openstack::Service['heat'],
    ],
  }

  $conf_default = {
    # [database]
    # connection = mysql+pymysql://heat:HEAT_DBPASS@controller/heat
    'database/connection'                     => "mysql+pymysql://${heat_dbuser}:${heat_dbpass}@controller/${heat_dbname}",
    # [DEFAULT]
    # transport_url = rabbit://openstack:RABBIT_PASS@controller
    'DEFAULT/transport_url'                   => "rabbit://${rabbitmq_user}:${rabbit_pass}@controller",
    # [keystone_authtoken]
    # ...
    # www_authenticate_uri = http://controller:5000
    # auth_url = http://controller:5000
    # memcached_servers = controller:11211
    # auth_type = password
    # project_domain_name = default
    # user_domain_name = default
    # project_name = service
    # username = heat
    # password = HEAT_PASS
    'keystone_authtoken/www_authenticate_uri' => 'http://controller:5000',
    'keystone_authtoken/auth_url'             => 'http://controller:5000',
    'keystone_authtoken/memcached_servers'    => "${memcached_host}:${memcached_port}",
    'keystone_authtoken/auth_type'            => 'password',
    'keystone_authtoken/project_domain_name'  => 'Default',
    'keystone_authtoken/user_domain_name'     => 'Default',
    'keystone_authtoken/project_name'         => 'service',
    'keystone_authtoken/username'             => 'heat',
    'keystone_authtoken/password'             => $heat_pass,
    # [trustee]
    # ...
    # auth_type = password
    # auth_url = http://controller:5000
    # username = heat
    # password = HEAT_PASS
    # user_domain_name = default
    'trustee/auth_type'                       => 'password',
    'trustee/auth_url'                        => 'http://controller:5000',
    'trustee/username'                        => 'heat',
    'trustee/password'                        => $heat_pass,
    'trustee/user_domain_name'                => 'default',
    # [clients_keystone]
    # ...
    # auth_uri = http://controller:5000
    'clients_keystone/auth_uri'               => 'http://controller:5000',
    # [DEFAULT]
    # ...
    # heat_metadata_server_url = http://controller:8000
    # heat_waitcondition_server_url = http://controller:8000/v1/waitcondition
    'DEFAULT/heat_metadata_server_url'        => 'http://controller:8000',
    'DEFAULT/heat_waitcondition_server_url'   => 'http://controller:8000/v1/waitcondition',
    # [DEFAULT]
    # ...
    # stack_domain_admin = heat_domain_admin
    # stack_domain_admin_password = HEAT_DOMAIN_PASS
    # stack_user_domain_name = heat
    'DEFAULT/stack_domain_admin'              => 'heat_domain_admin',
    'DEFAULT/stack_domain_admin_password'     => $heat_domain_pass,
  }

  # https://docs.openstack.org/glance/latest/configuration/configuring.html#configuring-glance-storage-backends

  openstack::config { '/etc/heat/heat.conf':
    content => $conf_default,
    require => Openstack::Package['openstack-heat-api'],
    notify  => Exec['heat-db-sync'],
  }

  if $facts['os']['family'] == 'Debian' {
    service {
      default:
        ensure  => running,
        enable  => true,
        require => Exec['heat-db-sync']
      ;
      'heat-api': ;
      'heat-api-cfn': ;
      'heat-engine': ;
    }
  }
  else {
    service {
      default:
        ensure  => running,
        enable  => true,
        require => Exec['heat-db-sync']
      ;
      'openstack-heat-api': ;
      'openstack-heat-api-cfn': ;
      'openstack-heat-engine': ;
    }
  }

  Mysql_database <| title == $heat_dbname |> ~> Exec['heat-db-sync']
}
