# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::neutron
class openstack::controller::neutron (
  Openstack::Release
          $cycle                     = $openstack::cycle,
  String  $neutron_pass              = $openstack::neutron_pass,
  String  $neutron_dbname            = $openstack::neutron_dbname,
  String  $neutron_dbuser            = $openstack::neutron_dbuser,
  String  $neutron_dbpass            = $openstack::neutron_dbpass,
  String  $database_tag              = $openstack::database_tag,
  String  $metadata_secret           = $openstack::metadata_secret,
  String  $admin_pass                = $openstack::admin_pass,
  String  $nova_pass                 = $openstack::nova_pass,
  String  $provider_physical_network = $openstack::provider_physical_network,
  String  $ml2_extension_drivers     = $openstack::neutron_ml2_extension_drivers,
  Enum['linuxbridge', 'openvswitch']
          $network_plugin            = $openstack::neutron_network_plugin,
)
{
  include openstack::params
  # https://docs.openstack.org/releasenotes/neutron/victoria.html
  include openstack::neutron::core

  # https://docs.openstack.org/neutron/train/install/controller-install-rdo.html
  openstack::database { $neutron_dbname:
    dbuser       => $neutron_dbuser,
    dbpass       => $neutron_dbpass,
    database_tag => $database_tag,
  }

  # create neutron service user
  openstack::user { 'neutron':
    role      => 'admin',
    project   => 'service',
    user_pass => $neutron_pass,
    require   => Openstack::Project['service'],
  }

  openstack::service { 'neutron':
    service     => 'network',
    description => 'OpenStack Networking',
    endpoint    => {
      public   => 'http://controller:9696',
      internal => 'http://controller:9696',
      admin    => 'http://controller:9696',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['neutron'],
  }

  # https://docs.openstack.org/neutron/train/install/controller-install-option2-rdo.html
  openstack::package {
    default:
      cycle => $cycle,
    ;
    'openstack-neutron':
      configs => [
        '/etc/neutron/l3_agent.ini',
        '/etc/neutron/dhcp_agent.ini',
        '/etc/neutron/metadata_agent.ini',
      ],
      before  => Openstack::Config['/etc/neutron/plugins/ml2/linuxbridge_agent.ini'],
    ;
    'openstack-neutron-ml2':
      configs => [
        '/etc/neutron/plugins/ml2/ml2_conf.ini',
      ],
    ;
  }

  $ovs_bridge = 'br-provider'

  if $network_plugin == 'openvswitch' {
    if $facts['os']['release']['major'] == '7' {
      $ovs_package = 'openvswitch'
    }
    else {
      $ovs_package = 'rdo-openvswitch'
    }

    # Install OVS
    openstack::package { $ovs_package:
      cycle => $cycle,
    }

    # Start the OVS service
    service { 'openvswitch':
      ensure  => running,
      enable  => true,
      require => Openstack::Package[$ovs_package],
    }

    # Create the OVS provider bridge
    exec { "ovs-vsctl add-br ${ovs_bridge}":
      path    => '/usr/bin:/usr/sbin',
      unless  => "test -d /sys/devices/virtual/net/${ovs_bridge}",
      require => Service['openvswitch'],
    }

    openstack::config { '/etc/neutron/plugins/ml2/openvswitch_agent.ini/controller':
      path    => '/etc/neutron/plugins/ml2/openvswitch_agent.ini',
      content => {
        'ovs/bridge_mappings'           => "provider:${ovs_bridge}",
        'securitygroup/firewall_driver' => 'iptables_hybrid',
      },
      require => [
        Openstack::Config['/etc/neutron/plugins/ml2/openvswitch_agent.ini'],
        Exec["ovs-vsctl add-br ${ovs_bridge}"],
      ],
      notify  => Service['neutron-openvswitch-agent'],
    }

    $neutron_interface_driver = 'openvswitch'
    $ml2_mechanism_drivers = 'openvswitch,l2population'
    $l3_content  = {
      # [DEFAULT]
      # interface_driver = openvswitch
      # external_network_bridge =
      'DEFAULT/interface_driver'        => $neutron_interface_driver,
      'DEFAULT/external_network_bridge' => '',
    }
  }
  else {
    $neutron_interface_driver = 'linuxbridge'
    $ml2_mechanism_drivers = 'linuxbridge,l2population'
    $l3_content  = {
      # [DEFAULT]
      # interface_driver = linuxbridge
      'DEFAULT/interface_driver' => $neutron_interface_driver,
    }
  }

  $conf_default = {
    # [database]
    # connection = mysql+pymysql://neutron:NEUTRON_DBPASS@controller/neutron
    'database/connection' => "mysql+pymysql://${neutron_dbuser}:${neutron_dbpass}@controller/${neutron_dbname}",
    # [DEFAULT]
    # core_plugin = ml2
    # service_plugins = router
    # allow_overlapping_ips = true
    'DEFAULT/core_plugin'           => 'ml2',
    'DEFAULT/service_plugins'       => 'router',
    'DEFAULT/allow_overlapping_ips' => 'true',
    # [DEFAULT]
    # notify_nova_on_port_status_changes = true
    # notify_nova_on_port_data_changes = true
    'DEFAULT/notify_nova_on_port_status_changes'        => 'true',
    'DEFAULT/notify_nova_on_port_data_changes'          => 'true',
    # [nova]
    # auth_url = http://controller:5000
    # auth_type = password
    # project_domain_name = default
    # user_domain_name = default
    # region_name = RegionOne
    # project_name = service
    # username = nova
    # password = NOVA_PASS
    'nova/auth_url'                                     => 'http://controller:5000',
    'nova/auth_type'                                    => 'password',
    'nova/project_domain_name'                          => 'default',
    'nova/user_domain_name'                             => 'default',
    'nova/region_name'                                  => 'RegionOne',
    'nova/project_name'                                 => 'service',
    'nova/username'                                     => 'nova',
    'nova/password'                                     => $nova_pass,
  }

  $ml2_default = {
    # [ml2]
    # type_drivers = flat,vlan,vxlan
    # tenant_network_types = vxlan
    # mechanism_drivers = linuxbridge,l2population
    # extension_drivers = port_security
    'ml2/type_drivers'            => 'flat,vlan,vxlan',
    'ml2/tenant_network_types'    => 'vxlan',
    'ml2/mechanism_drivers'       => $ml2_mechanism_drivers,
    'ml2/extension_drivers'       => $ml2_extension_drivers,
    # [ml2_type_flat]
    # flat_networks = provider
    'ml2_type_flat/flat_networks' => $provider_physical_network,
    # [ml2_type_vxlan]
    # vni_ranges = 1:1000
    'ml2_type_vxlan/vni_ranges'   => '1:1000',
    # [securitygroup]
    # enable_ipset = true
    'securitygroup/enable_ipset'  => 'true',
  }

  openstack::config { '/etc/neutron/neutron.conf/controller':
    path    => '/etc/neutron/neutron.conf',
    content => $conf_default,
    require => Openstack::Config['/etc/neutron/neutron.conf'],
    notify  => Exec['neutron-db-sync'],
  }

  openstack::config { '/etc/neutron/plugins/ml2/ml2_conf.ini':
    content => $ml2_default,
    require => [
      Openstack::Package['openstack-neutron'],
      Openstack::Package['openstack-neutron-ml2'],
    ],
    notify  => [
      Exec['neutron-db-sync'],
      Service['neutron-server'],
    ],
  }

  file { '/etc/neutron/plugin.ini':
    ensure  => 'link',
    target  => '/etc/neutron/plugins/ml2/ml2_conf.ini',
    require => Openstack::Config['/etc/neutron/plugins/ml2/ml2_conf.ini'],
  }

  openstack::config { '/etc/neutron/l3_agent.ini':
    content => $l3_content,
    require => Openstack::Package['openstack-neutron'],
    notify  => Service['neutron-l3-agent'],
  }

  # https://docs.openstack.org/neutron/train/install/controller-install-option2-rdo.html#configure-the-dhcp-agent
  # [DEFAULT]
  # interface_driver = linuxbridge
  # dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
  # enable_isolated_metadata = true
  openstack::config { '/etc/neutron/dhcp_agent.ini':
    content => {
            'DEFAULT/interface_driver'         => $neutron_interface_driver,
            'DEFAULT/dhcp_driver'              => 'neutron.agent.linux.dhcp.Dnsmasq',
            'DEFAULT/enable_isolated_metadata' => 'true',
    },
    require => Openstack::Package['openstack-neutron'],
    notify  => Service['neutron-dhcp-agent'],
  }

  # [DEFAULT]
  # nova_metadata_host = controller
  # metadata_proxy_shared_secret = METADATA_SECRET
  openstack::config { '/etc/neutron/metadata_agent.ini':
    content => {
      'DEFAULT/nova_metadata_host'           => 'controller',
      'DEFAULT/metadata_proxy_shared_secret' => $metadata_secret,
    },
    require => Openstack::Package['openstack-neutron'],
    notify  => Service['neutron-metadata-agent'],
  }

  # [neutron]
  # auth_url = http://controller:5000
  # auth_type = password
  # project_domain_name = default
  # user_domain_name = default
  # region_name = RegionOne
  # project_name = service
  # username = neutron
  # password = NEUTRON_PASS
  # service_metadata_proxy = true
  # metadata_proxy_shared_secret = METADATA_SECRET
  openstack::config { '/etc/nova/nova.conf/neutron':
    path    => '/etc/nova/nova.conf',
    content => {
      'neutron/auth_url'                     => 'http://controller:5000',
      'neutron/auth_type'                    => 'password',
      'neutron/project_domain_name'          => 'default',
      'neutron/user_domain_name'             => 'default',
      'neutron/region_name'                  => 'RegionOne',
      'neutron/project_name'                 => 'service',
      'neutron/username'                     => 'neutron',
      'neutron/password'                     => $neutron_pass,
      'neutron/service_metadata_proxy'       => 'true',
      'neutron/metadata_proxy_shared_secret' => $metadata_secret,
    },
    require => Openstack::Config['/etc/nova/nova.conf'],
    notify  => Service['openstack-nova-api'],
  }

  exec { 'neutron-db-sync':
    command     => 'neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head', # lint:ignore:140chars
    path        => '/bin:/sbin:/usr/bin:/usr/sbin',
    cwd         => '/var/lib/neutron',
    user        => 'neutron',
    refreshonly => true,
    require     => [
      File['/var/lib/neutron'],
      File['/etc/neutron/plugin.ini'],
      Openstack::Service['neutron'],
    ]
  }

  service {
    default:
      ensure    => running,
      enable    => true,
      require   => File['/var/lib/neutron'],
      subscribe => [
        Openstack::Config['/etc/neutron/neutron.conf'],
        Openstack::Config['/etc/neutron/neutron.conf/controller'],
        Exec['neutron-db-sync'],
      ],
    ;
    'neutron-server':
    ;
    'neutron-dhcp-agent':
    ;
    'neutron-metadata-agent':
    ;
    'neutron-l3-agent':
    ;
  }

  Mysql_database <| title == $neutron_dbname |> ~> Exec['neutron-db-sync']

  Openstack::Package['openstack-neutron'] -> Openstack::Config['/etc/neutron/neutron.conf']

  Openstack::Config['/etc/neutron/plugins/ml2/linuxbridge_agent.ini'] ~> Exec['neutron-db-sync']
  Openstack::Config['/etc/neutron/neutron.conf'] ~> Exec['neutron-db-sync']

  Openstack::Config['/etc/neutron/neutron.conf/controller'] ~> Service['neutron-linuxbridge-agent']
  Exec['neutron-db-sync'] ~> Service['neutron-linuxbridge-agent']

  if $network_plugin == 'openvswitch' {
    Openstack::Config['/etc/neutron/plugins/ml2/openvswitch_agent.ini'] ~> Exec['neutron-db-sync']
    Openstack::Config['/etc/neutron/neutron.conf/controller'] ~> Service['neutron-openvswitch-agent']
    Exec['neutron-db-sync'] ~> Service['neutron-openvswitch-agent']
  }
  else {
    Openstack::Config['/etc/neutron/plugins/ml2/linuxbridge_agent.ini'] ~> Exec['neutron-db-sync']
    Openstack::Config['/etc/neutron/neutron.conf/controller'] ~> Service['neutron-linuxbridge-agent']
    Exec['neutron-db-sync'] ~> Service['neutron-linuxbridge-agent']
  }
}
