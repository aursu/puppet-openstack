# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::neutron
class openstack::controller::neutron (
  Openstack::Release
          $cycle                     = $openstack::cycle,
  String  $neutron_dbname            = $openstack::neutron_dbname,
  String  $neutron_dbuser            = $openstack::neutron_dbuser,
  String  $neutron_dbpass            = $openstack::neutron_dbpass,
  String  $database_tag              = $openstack::database_tag,
  String  $neutron_pass              = $openstack::neutron_pass,
  String  $metadata_secret           = $openstack::metadata_secret,
  String  $admin_pass                = $openstack::admin_pass,
  String  $nova_pass                 = $openstack::nova_pass,
  String  $provider_physical_network = $openstack::provider_physical_network,
  String  $provider_interface_name   = $openstack::provider_interface_name,
  Stdlib::IP::Address
          $mgmt_interface_ip_address = $openstack::mgmt_interface_ip_address,

  Stdlib::Host
          $memcached_host            = $openstack::memcached_host,
  Integer $memcached_port            = $openstack::memcached_port,
  String  $rabbitmq_user             = $openstack::rabbitmq_user,
  String  $rabbit_pass               = $openstack::rabbit_pass,
)
{
  # https://docs.openstack.org/neutron/train/install/controller-install-rdo.html

  $overlay_interface_ip_address = $mgmt_interface_ip_address

  openstack::database { $neutron_dbname:
    dbuser       => $neutron_dbuser,
    dbpass       => $neutron_dbpass,
    database_tag => $database_tag,
  }

  # create neutron service user
  openstack::user { 'neutron':
    role       => 'admin',
    project    => 'service',
    user_pass  => $neutron_pass,
    admin_pass => $admin_pass,
    require    => Openstack::Project['service'],
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

  package { 'ebtables':
    ensure => 'present',
  }

  # https://docs.openstack.org/neutron/train/install/controller-install-option2-rdo.html
  openstack::package {
    default:
      cycle => $cycle,
    ;
    'openstack-neutron':
      configs => [
        '/etc/neutron/neutron.conf',
        '/etc/neutron/l3_agent.ini',
        '/etc/neutron/dhcp_agent.ini',
        '/etc/neutron/metadata_agent.ini'
      ],
    ;
    'openstack-neutron-ml2':
      configs => [
        '/etc/neutron/plugins/ml2/ml2_conf.ini',
      ],
    ;
    'openstack-neutron-linuxbridge':
      configs => [
        '/etc/neutron/plugins/ml2/linuxbridge_agent.ini',
      ],
    ;
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
    # transport_url = rabbit://openstack:RABBIT_PASS@controller
    'DEFAULT/transport_url'         => "rabbit://${rabbitmq_user}:${rabbit_pass}@controller",
    # [DEFAULT]
    # auth_strategy = keystone
    'DEFAULT/auth_strategy'         => 'keystone',
    # [keystone_authtoken]
    # www_authenticate_uri = http://controller:5000
    # auth_url = http://controller:5000
    # memcached_servers = controller:11211
    # auth_type = password
    # project_domain_name = default
    # user_domain_name = default
    # project_name = service
    # username = neutron
    # password = NEUTRON_PASS
    'keystone_authtoken/www_authenticate_uri' => 'http://controller:5000',
    'keystone_authtoken/auth_url'             => 'http://controller:5000',
    'keystone_authtoken/memcached_servers'    => "${memcached_host}:${memcached_port}",
    'keystone_authtoken/auth_type'            => 'password',
    'keystone_authtoken/project_domain_name'  => 'default',
    'keystone_authtoken/user_domain_name'     => 'default',
    'keystone_authtoken/project_name'         => 'service',
    'keystone_authtoken/username'             => 'neutron',
    'keystone_authtoken/password'             => $neutron_pass,
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
    # [oslo_concurrency]
    # lock_path = /var/lib/neutron/tmp
    'oslo_concurrency/lock_path'                        => '/var/lib/neutron/tmp',
  }

  $ml2_default = {
    # [ml2]
    # type_drivers = flat,vlan,vxlan
    # tenant_network_types = vxlan
    # mechanism_drivers = linuxbridge,l2population
    # extension_drivers = port_security
    'ml2/type_drivers'            => 'flat,vlan,vxlan',
    'ml2/tenant_network_types'    => 'vxlan',
    'ml2/mechanism_drivers'       => 'linuxbridge,l2population',
    'ml2/extension_drivers'       => 'port_security',
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

  $lb_default = {
    # [linux_bridge]
    # physical_interface_mappings = provider:PROVIDER_INTERFACE_NAME
    'linux_bridge/physical_interface_mappings' => "${provider_physical_network}:${provider_interface_name}",
    # [vxlan]
    # enable_vxlan = true
    # local_ip = OVERLAY_INTERFACE_IP_ADDRESS
    # l2_population = true
    'vxlan/enable_vxlan'                       => 'true',
    'vxlan/local_ip'                           => $overlay_interface_ip_address,
    'vxlan/l2_population'                      => 'true',
    # [securitygroup]
    # enable_security_group = true
    # firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
    'securitygroup/enable_security_group'       => 'true',
    'securitygroup/firewall_driver'             => 'neutron.agent.linux.iptables_firewall.IptablesFirewallDriver',
  }

  openstack::config { '/etc/neutron/neutron.conf':
    content => $conf_default,
    require => Openstack::Package['openstack-neutron'],
    notify  => Exec['neutron-db-sync'],
  }

  openstack::config { '/etc/neutron/plugins/ml2/ml2_conf.ini':
    content => $ml2_default,
    require => [
      Openstack::Package['openstack-neutron'],
      Openstack::Package['openstack-neutron-ml2'],
    ],
    notify  => Exec['neutron-db-sync'],
  }

  file { '/etc/neutron/plugin.ini':
    ensure  => 'link',
    target  => '/etc/neutron/plugins/ml2/ml2_conf.ini',
    require => Openstack::Config['/etc/neutron/plugins/ml2/ml2_conf.ini'],
  }

  openstack::config { '/etc/neutron/plugins/ml2/linuxbridge_agent.ini':
    content => $lb_default,
    require => [
      Openstack::Package['openstack-neutron'],
      Openstack::Package['openstack-neutron-linuxbridge'],
    ],
    notify  => [
      Exec['neutron-db-sync'],
      Service['neutron-linuxbridge-agent'],
    ],
  }

  # [DEFAULT]
  # interface_driver = linuxbridge
  openstack::config { '/etc/neutron/l3_agent.ini':
    content => {
      'DEFAULT/interface_driver' => 'linuxbridge',
    },
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
            'DEFAULT/interface_driver'         => 'linuxbridge',
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

  # Identities
  group { 'neutron':
    ensure => present,
    system => true,
  }

  user { 'neutron':
    ensure  => present,
    system  => true,
    gid     => 'neutron',
    comment => 'OpenStack Neutron Daemons',
    home    => '/var/lib/neutron',
    shell   => '/sbin/nologin',
    require => Group['neutron']
  }

  file { '/var/lib/neutron':
    ensure  => directory,
    owner   => 'neutron',
    group   => 'neutron',
    mode    => '0711',
    require => User['neutron'],
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

  # Ensure your Linux operating system kernel supports network bridge filters
  kmod::load { 'br_netfilter': }

  sysctl {
    default:
      value   => 1,
      require => Kmod::Load['br_netfilter'],
    ;
    'net.bridge.bridge-nf-call-iptables':
    ;
    'net.bridge.bridge-nf-call-ip6tables':
    ;
  }

  service {
    default:
      ensure    => running,
      enable    => true,
      require   => File['/var/lib/neutron'],
      subscribe => [
        Openstack::Config['/etc/neutron/neutron.conf'],
        Exec['neutron-db-sync'],
      ],
    ;
    'neutron-server':
    ;
    'neutron-linuxbridge-agent':
    ;
    'neutron-dhcp-agent':
    ;
    'neutron-metadata-agent':
    ;
    'neutron-l3-agent':
    ;
  }

  Mysql_database <| title == $neutron_dbname |> ~> Exec['neutron-db-sync']
}
