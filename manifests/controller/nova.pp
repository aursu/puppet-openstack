# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::nova
class openstack::controller::nova (
  Openstack::Release
          $cycle                     = $openstack::cycle,
  String  $nova_pass                 = $openstack::nova_pass,
  String  $nova_dbname               = $openstack::nova_dbname,
  String  $nova_dbuser               = $openstack::nova_dbuser,
  String  $nova_dbpass               = $openstack::nova_dbpass,
  String  $database_tag              = $openstack::database_tag,
  String  $admin_pass                = $openstack::admin_pass,
  String  $placement_pass            = $openstack::placement_pass,
  Stdlib::Host
          $memcached_host            = $openstack::memcached_host,
  Integer $memcached_port            = $openstack::memcached_port,
  String  $rabbitmq_user             = $openstack::rabbitmq_user,
  Integer $rabbitmq_port             = $openstack::rabbitmq_port,
  String  $rabbit_pass               = $openstack::rabbit_pass,
  Stdlib::IP::Address
          $mgmt_interface_ip_address = $openstack::mgmt_interface_ip_address,

){
  # https://docs.openstack.org/nova/train/install/controller-install-rdo.html

  # API database for Nova
  $nova_api_dbname = "${nova_dbname}_api"

  # Placement database
  $nova_placement_dbname = "${nova_dbname}_cell0"

  openstack::database {
    default:
      dbuser       => $nova_dbuser,
      dbpass       => $nova_dbpass,
      database_tag => $database_tag,
    ;
    $nova_dbname:
    ;
    $nova_api_dbname:
      usercreate => false,
    ;
    $nova_placement_dbname:
      usercreate => false,
    ;
  }

  openstack::user { 'nova':
    role       => 'admin',
    project    => 'service',
    user_pass  => $nova_pass,
    admin_pass => $admin_pass,
    require    => Openstack::Project['service'],
  }

  openstack::service { 'nova':
    service     => 'compute',
    description => 'OpenStack Computec',
    endpoint    => {
      public   => 'http://controller:8774/v2.1',
      internal => 'http://controller:8774/v2.1',
      admin    => 'http://controller:8774/v2.1',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['nova'],
  }

  openstack::package {
    default:
      cycle => $cycle,
    ;
    'openstack-nova-api':
      configs => [
          '/etc/nova/nova.conf',
      ],
    ;
    'openstack-nova-conductor':
    ;
    'openstack-nova-novncproxy':
    ;
    'openstack-nova-scheduler':
    ;
  }

  # Identities
  group { 'nova':
    ensure => present,
    system => true,
  }

  user { 'nova':
    ensure     => present,
    system     => true,
    gid        => 'nova',
    comment    => 'OpenStack Nova Daemons',
    home       => '/var/lib/nova',
    shell      => '/sbin/nologin',
    managehome => true,
  }

  file { '/var/lib/nova':
    ensure  => directory,
    owner   => 'nova',
    group   => 'nova',
    mode    => '0711',
    require => User['nova'],
  }

  exec {
    default:
      cwd         => '/var/lib/nova',
      user        => 'nova',
      path        => '/bin:/sbin:/usr/bin:/usr/sbin',
      refreshonly => true,
      require     => File['/var/lib/nova'],
    ;
    'nova-db-sync':
      command => 'nova-manage db sync',
      require => [
        File['/var/lib/nova'],
        Openstack::Service['nova'],
      ],
    ;
    'nova-create-cell1':
      command => 'nova-manage cell_v2 create_cell --name=cell1',
      unless  => 'nova-manage cell_v2 list_cells | grep cell1',
    ;
    'nova-map_cell0':
      command => 'nova-manage cell_v2 map_cell0',
      notify  => [
        Exec['nova-db-sync'],
        Exec['nova-create-cell1'],
      ],
    ;
    'nova-api_db-sync':
      command => 'nova-manage api_db sync',
      require => [
        File['/var/lib/nova'],
        Openstack::Service['nova'],
      ],
      notify  => Exec['nova-map_cell0'],
    ;
  }

  # /etc/nova/nova.conf
  #   [DEFAULT]
  # # ...
  # enabled_apis = osapi_compute,metadata
  $conf_default = {
    'DEFAULT/enabled_apis'                              => 'osapi_compute,metadata',
    # [database]
    # # ...
    # connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova
    'database/connection'     => "mysql+pymysql://${nova_dbuser}:${nova_dbpass}@controller/${nova_dbname}",
    # [api_database]
    # # ...
    # connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova_api
    'api_database/connection' => "mysql+pymysql://${nova_dbuser}:${nova_dbpass}@controller/${nova_api_dbname}",
    # [DEFAULT]
    # # ...
    # transport_url = rabbit://openstack:RABBIT_PASS@controller:5672/
    'DEFAULT/transport_url'   => "rabbit://${rabbitmq_user}:${rabbit_pass}@controller:${rabbitmq_port}/",
    # [api]
    # # ...
    # auth_strategy = keystone
    'api/auth_strategy'       => 'keystone',

    # [keystone_authtoken]
    # # ...
    # www_authenticate_uri = http://controller:5000/
    # auth_url = http://controller:5000/
    # memcached_servers = controller:11211
    # auth_type = password
    # project_domain_name = Default
    # user_domain_name = Default
    # project_name = service
    # username = nova
    # password = NOVA_PASS
    'keystone_authtoken/www_authenticate_uri' => 'http://controller:5000/',
    'keystone_authtoken/auth_url'             => 'http://controller:5000/',
    'keystone_authtoken/memcached_servers'    => "${memcached_host}:${memcached_port}",
    'keystone_authtoken/auth_type'            => 'password',
    'keystone_authtoken/project_domain_name'  => 'Default',
    'keystone_authtoken/user_domain_name'     => 'Default',
    'keystone_authtoken/project_name'         => 'service',
    'keystone_authtoken/username'             => 'nova',
    'keystone_authtoken/password'             => $nova_pass,
    # [DEFAULT]
    # # ...
    # my_ip = 10.0.0.11
    'DEFAULT/my_ip'                           => $mgmt_interface_ip_address,
    # [DEFAULT]
    # # ...
    # use_neutron = true
    # firewall_driver = nova.virt.firewall.NoopFirewallDriver
    'DEFAULT/use_neutron'                     => 'True',
    'DEFAULT/firewall_driver'                 => 'nova.virt.firewall.NoopFirewallDriver',
    # [vnc]
    # enabled = true
    # # ...
    # server_listen = $my_ip
    # server_proxyclient_address = $my_ip
    'vnc/enabled'                             => 'true',
    'vnc/server_listen'                       => '$my_ip',
    'vnc/server_proxyclient_address'          => '$my_ip',
    # [glance]
    # # ...
    # api_servers = http://controller:9292
    'glance/api_servers'                      => 'http://controller:9292',
    # [oslo_concurrency]
    # # ...
    # lock_path = /var/lib/nova/tmp
    'oslo_concurrency/lock_path'              => '/var/lib/nova/tmp',
    # [placement]
    # # ...
    # region_name = RegionOne
    # project_domain_name = Default
    # project_name = service
    # auth_type = password
    # user_domain_name = Default
    # auth_url = http://controller:5000/v3
    # username = placement
    # password = PLACEMENT_PASS
    'placement/region_name'                   => 'RegionOne',
    'placement/project_domain_name'           => 'Default',
    'placement/project_name'                  => 'service',
    'placement/auth_type'                     => 'password',
    'placement/user_domain_name'              => 'Default',
    'placement/auth_url'                      => 'http://controller:5000/v3',
    'placement/username'                      => 'placement',
    'placement/password'                      => $placement_pass,
  }

  openstack::config { '/etc/nova/nova.conf':
    content => $conf_default,
    require => Openstack::Package['openstack-nova-api'],
    notify  => [
      Exec['nova-api_db-sync'],
      Exec['nova-db-sync'],
      Exec['nova-map_cell0'],
    ],
  }

  service {
    default:
      ensure    => running,
      enable    => true,
      require   => File['/var/lib/nova'],
      subscribe => Openstack::Config['/etc/nova/nova.conf'],
    ;
    'openstack-nova-api':
    ;
    'openstack-nova-scheduler':
    ;
    'openstack-nova-conductor':
    ;
    'openstack-nova-novncproxy':
    ;
  }

  Mysql_database <| title == $nova_api_dbname |> ~> Exec['nova-api_db-sync']
  Mysql_database <| title == $nova_dbname |> ~> Exec['nova-db-sync']
  Mysql_database <| title == $nova_placement_dbname |> ~> Exec['nova-map_cell0']
}
