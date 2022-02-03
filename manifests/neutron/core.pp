# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::neutron::core
class openstack::neutron::core (
  Openstack::Release
          $cycle                     = $openstack::cycle,
  String  $neutron_pass              = $openstack::neutron_pass,

  String  $provider_physical_network = $openstack::provider_physical_network,
  String  $provider_interface_name   = $openstack::provider_interface_name,
  Stdlib::IP::Address
          $mgmt_interface_ip_address = $openstack::mgmt_interface_ip_address,

  String  $rabbitmq_user             = $openstack::rabbitmq_user,
  Stdlib::Host
          $rabbitmq_host             = $openstack::rabbitmq_host,
  Integer $rabbitmq_port             = $openstack::rabbitmq_port,
  String  $rabbit_pass               = $openstack::rabbit_pass,
  Stdlib::Host
          $memcached_host            = $openstack::memcached_host,
  Integer $memcached_port            = $openstack::memcached_port,
  Stdlib::Host
          $controller_host           = $openstack::controller_host,
  Enum['linuxbridge', 'openvswitch']
          $network_plugin            = $openstack::neutron_network_plugin,
)
{
  $overlay_interface_ip_address = $mgmt_interface_ip_address

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

  package {
    default:
      ensure => present,
    ;
    'ipset': ;
    'ebtables': ;
  }

  # neutron needs sqlalchemy-1.3.23+
  package { 'python3-sqlalchemy':
    ensure => 'latest',
  }

  openstack::package {
    default:
      cycle => $cycle,
    ;
    'openstack-neutron-common':
      configs => [
        '/etc/neutron/neutron.conf',
      ],
    ;
    'conntrack-tools': ;
  }

  $lb_default = {
    ### map the provider virtual network to the provider physical network interface
    # [linux_bridge]
    # physical_interface_mappings = provider:PROVIDER_INTERFACE_NAME
    'linux_bridge/physical_interface_mappings' => "${provider_physical_network}:${provider_interface_name}",

    ### enable VXLAN overlay networks, configure the IP address of the physical
    ### network interface that handles overlay networks, and enable layer-2
    ### population
    # [vxlan]
    # enable_vxlan = true
    # local_ip = OVERLAY_INTERFACE_IP_ADDRESS
    # l2_population = true
    'vxlan/enable_vxlan'                       => 'true',
    'vxlan/local_ip'                           => $overlay_interface_ip_address,
    'vxlan/l2_population'                      => 'true',

    ### enable security groups and configure the Linux bridge iptables firewall driver
    # [securitygroup]
    # enable_security_group = true
    # firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
    'securitygroup/enable_security_group'       => 'true',
    'securitygroup/firewall_driver'             => 'neutron.agent.linux.iptables_firewall.IptablesFirewallDriver',
  }

  $ovs_default = {
    'ovs/local_ip'        => $overlay_interface_ip_address,
    'agent/tunnel_types'  => 'vxlan',
    'agent/l2_population' => 'true',
  }

  if $network_plugin == 'openvswitch' {
    # https://docs.openstack.org/newton/networking-guide/deploy-ovs-selfservice.html
    openstack::package { 'openstack-neutron-openvswitch':
      cycle   => $cycle,
      configs => [
        '/etc/neutron/plugins/ml2/openvswitch_agent.ini',
      ],
      require => Openstack::Package['openstack-neutron-common'],
    }

    openstack::config { '/etc/neutron/plugins/ml2/openvswitch_agent.ini':
      content => $ovs_default,
      require => Openstack::Package['openstack-neutron-openvswitch'],
      notify  => Service['neutron-openvswitch-agent'],
    }

    service { 'neutron-openvswitch-agent':
      ensure    => running,
      enable    => true,
      require   => File['/var/lib/neutron'],
      subscribe => Openstack::Config['/etc/neutron/neutron.conf'],
    }

    # linuxbridge decomission
    service { 'neutron-linuxbridge-agent': ensure => stopped, }
    package { 'openstack-neutron-linuxbridge':
      ensure  => absent,
      require => Service['neutron-linuxbridge-agent'],
      before  => Service['neutron-openvswitch-agent'],
    }
  }
  else {
    openstack::package { 'openstack-neutron-linuxbridge':
      cycle   => $cycle,
      configs => [
        '/etc/neutron/plugins/ml2/linuxbridge_agent.ini',
      ],
      require => Openstack::Package['openstack-neutron-common'],
    }

    # The Linux bridge agent builds layer-2 (bridging and switching) virtual
    # networking infrastructure for instances and handles security groups.
    openstack::config { '/etc/neutron/plugins/ml2/linuxbridge_agent.ini':
      content => $lb_default,
      require => Openstack::Package['openstack-neutron-linuxbridge'],
      notify  => Service['neutron-linuxbridge-agent'],
    }

    service { 'neutron-linuxbridge-agent':
      ensure    => running,
      enable    => true,
      require   => File['/var/lib/neutron'],
      subscribe => Openstack::Config['/etc/neutron/neutron.conf'],
    }

    # openvswitch decomission
    service { 'neutron-openvswitch-agent': ensure => stopped, }
    package { 'openstack-neutron-openvswitch':
      ensure  => absent,
      require => Service['neutron-openvswitch-agent'],
      before  => Service['neutron-linuxbridge-agent'],
    }
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

  $conf_default = {
    ### RabbitMQ message queue access
    # [DEFAULT]
    # transport_url = rabbit://openstack:RABBIT_PASS@controller:5672/
    'DEFAULT/transport_url'                   => "rabbit://${rabbitmq_user}:${rabbit_pass}@${rabbitmq_host}:${rabbitmq_port}/",
    ### configure Identity service access
    # [DEFAULT]
    # auth_strategy = keystone
    'DEFAULT/auth_strategy'                   => 'keystone',
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
    'keystone_authtoken/www_authenticate_uri' => "http://${controller_host}:5000",
    'keystone_authtoken/auth_url'             => "http://${controller_host}:5000",
    'keystone_authtoken/memcached_servers'    => "${memcached_host}:${memcached_port}",
    'keystone_authtoken/auth_type'            => 'password',
    'keystone_authtoken/project_domain_name'  => 'default',
    'keystone_authtoken/user_domain_name'     => 'default',
    'keystone_authtoken/project_name'         => 'service',
    'keystone_authtoken/username'             => 'neutron',
    'keystone_authtoken/password'             => $neutron_pass,
    # [oslo_concurrency]
    # lock_path = /var/lib/neutron/tmp
    'oslo_concurrency/lock_path'              => '/var/lib/neutron/tmp',
  }

  openstack::config { '/etc/neutron/neutron.conf':
    content => $conf_default,
    require => Openstack::Package['openstack-neutron-common'],
  }
}
