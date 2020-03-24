# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::nova
class openstack::controller::nova (
  Openstack::Release
          $cycle        = $openstack::cycle,
  String  $nova_pass    = $openstack::nova_pass,
  String  $nova_dbname  = $openstack::nova_dbname,
  String  $nova_dbuser  = $openstack::nova_dbuser,
  String  $nova_dbpass  = $openstack::nova_dbpass,
  String  $database_tag = $openstack::database_tag,
  String  $admin_pass   = $openstack::admin_pass,
  String  $compute_tag  = $openstack::compute_tag,
){
  # https://docs.openstack.org/nova/train/install/controller-install-rdo.html
  include openstack::nova::core

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
    'openstack-nova-conductor': ;
    'openstack-nova-novncproxy': ;
    'openstack-nova-scheduler': ;
  }

  exec {
    default:
      cwd         => '/var/lib/nova',
      user        => 'nova',
      path        => '/bin:/sbin:/usr/bin:/usr/sbin',
      refreshonly => true,
      require     => File['/var/lib/nova'],
      subscribe   => [
        Openstack::Config['/etc/nova/nova.conf'],
        Openstack::Config['/etc/nova/nova.conf/controller'],
      ],
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
  $conf_default = {
    # [database]
    # connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova
    'database/connection'                        => "mysql+pymysql://${nova_dbuser}:${nova_dbpass}@controller/${nova_dbname}",
    # [api_database]
    # connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova_api
    'api_database/connection'                    => "mysql+pymysql://${nova_dbuser}:${nova_dbpass}@controller/${nova_api_dbname}",
    # [vnc]
    # enabled = true
    # server_listen = $my_ip
    # server_proxyclient_address = $my_ip
    'vnc/enabled'                                => 'true',
    'vnc/server_listen'                          => '$my_ip',
    'vnc/server_proxyclient_address'             => '$my_ip',
    ### When you add new compute nodes, you must run nova-manage cell_v2 discover_hosts on the controller node
    ### to register those new compute nodes. Alternatively, you can set an appropriate interval
    # [scheduler]
    # discover_hosts_in_cells_interval = 300
    'scheduler/discover_hosts_in_cells_interval' => '300',
  }

  openstack::config { '/etc/nova/nova.conf/controller':
    content => $conf_default,
    require => Openstack::Config['/etc/nova/nova.conf'],
  }

  service {
    default:
      ensure    => running,
      enable    => true,
      require   => File['/var/lib/nova'],
      subscribe => [
        Openstack::Config['/etc/nova/nova.conf'],
        Openstack::Config['/etc/nova/nova.conf/controller'],
        Exec['nova-api_db-sync'],
        Exec['nova-db-sync'],
        Exec['nova-map_cell0'],
      ],
    ;
    'openstack-nova-api': ;
    'openstack-nova-scheduler': ;
    'openstack-nova-conductor': ;
    'openstack-nova-novncproxy': ;
  }

  # nova-manage cell_v2 discover_hosts
  Openstack::Nova::Host <<| tag == $compute_tag |>>

  Mysql_database <| title == $nova_api_dbname |> ~> Exec['nova-api_db-sync']
  Mysql_database <| title == $nova_dbname |> ~> Exec['nova-db-sync']
  Mysql_database <| title == $nova_placement_dbname |> ~> Exec['nova-map_cell0']

  Openstack::Package['openstack-nova-api'] -> Openstack::Config['/etc/nova/nova.conf']
}
