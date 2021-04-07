# @summary Install and configure the Load-balancer service, code-named Octavia, on the controller nod
#
# Octavia is an open source, operator-scale load balancing solution designed to work with OpenStack
# https://docs.openstack.org/octavia/latest/install/install.html
#
# @example
#   include openstack::controller::octavia
class openstack::controller::octavia (
  Openstack::Release
          $cycle             = $openstack::cycle,
  String  $octavia_pass      = $openstack::octavia_pass,
  String  $octavia_dbname    = $openstack::octavia_dbname,
  String  $octavia_dbuser    = $openstack::octavia_dbuser,
  String  $octavia_dbpass    = $openstack::octavia_dbpass,
  String  $database_tag      = $openstack::database_tag,
  String  $admin_pass        = $openstack::admin_pass,
  Stdlib::IP::Address
          $mgmt_subnet           = $openstack::octavia_mgmt_subnet,
  Stdlib::IP::Address
          $mgmt_subnet_start     = $openstack::octavia_mgmt_subnet_start,
  Stdlib::IP::Address
          $mgmt_subnet_end       = $openstack::octavia_mgmt_subnet_end,
  Stdlib::IP::Address
          $mgmt_port_ip          = $openstack::octavia_mgmt_port_ip,
  Stdlib::Host
          $mgmt_port_host        = $openstack::octavia_mgmt_port_host,
  Boolean $manage_dhcp_directory = $openstack::manage_dhcp_directory,
)
{
  # https://docs.openstack.org/octavia/latest/install/install-ubuntu.html
  include openstack::octavia::certs
  include openstack::octavia::ssh

  class { 'openstack::octavia::amphora':
    octavia_pass => $octavia_pass,
  }

  file { '/etc/octavia':
    ensure => 'directory',
  }

  openstack::database { $octavia_dbname:
    dbuser       => $octavia_dbuser,
    dbpass       => $octavia_dbpass,
    database_tag => $database_tag,
  }

  openstack::user { 'octavia':
    role         => 'admin',
    project      => 'service',
    user_pass    => $octavia_pass,
    setup_openrc => true,
    require      => Openstack::Project['service'],
  }

  openstack::service { 'octavia':
    service     => 'load-balancer',
    description => 'OpenStack Octavia',
    endpoint    => {
      public   => 'http://controller:9876',
      internal => 'http://controller:9876',
      admin    => 'http://controller:9876',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['octavia'],
  }

  $auth_octavia = {
    auth_username     => 'octavia',
    auth_password     => $octavia_pass,
    auth_project_name => 'service',
  }

  openstack_flavor { 'amphora':
    ensure     => present,
    disk       => 2,
    ram        => 1024,
    vcpus      => 1,
    visibility => 'private',
    require    => Openstack::User['octavia'],
    *          => $auth_octavia,
  }

  openstack::package {
    default:
      cycle   => $cycle,
    ;
    'openstack-octavia-api':
      configs       => [
        '/etc/octavia/octavia.conf',
      ],
      notifyconfigs => false,
    ;
    'openstack-octavia-health-manager': ;
    'openstack-octavia-housekeeping': ;
    'openstack-octavia-worker': ;
  }

  if $facts['os']['name'] in ['RedHat', 'CentOS'] {
    case $facts['os']['release']['major'] {
      '7': {
        package {
          default: ensure => 'installed';
          'python2-octavia': ;
          'python2-octaviaclient': ;
        }
      }
      default: {
          package {
            default: ensure => 'installed';
            'python3-octavia': ;
            'python3-octaviaclient': ;
          }
      }
    }
  }

  # Identities
  group { 'octavia':
    ensure => present,
    system => true,
  }

  user { 'octavia':
    ensure     => present,
    system     => true,
    gid        => 'octavia',
    comment    => 'OpenStack Octavia',
    home       => '/var/lib/octavia',
    managehome => true,
    shell      => '/sbin/nologin',
    require    => Group['octavia'],
  }

  file { '/var/lib/octavia':
    ensure  => directory,
    owner   => 'octavia',
    group   => 'octavia',
    mode    => '0711',
    require => User['octavia'],
  }

  # Create security groups and their rules
  openstack_security_group {
    default:
      *       => $auth_octavia,
      project => 'service',
      require => Openstack::User['octavia'],
    ;
    'service/lb-mgmt-sec-grp': ;
    'service/lb-health-mgr-sec-grp': ;
  }

  openstack_security_rule {
    default:
      *        => $auth_octavia,
      group    => 'lb-mgmt-sec-grp',
      project  => 'service',
      protocol => 'tcp',
      require  => Openstack::User['octavia'],
    ;
    'service/lb-mgmt-sec-grp/ingress/icmp/0.0.0.0/0/any':
      protocol   => 'icmp';
    'service/lb-mgmt-sec-grp/ingress/tcp/0.0.0.0/0/22:22':
      port_range => '22:22';
    'service/lb-mgmt-sec-grp/ingress/tcp/0.0.0.0/0/9443:9443':
      port_range => '9443:9443';
  }

  openstack_security_rule { 'service/lb-health-mgr-sec-grp/ingress/udp/0.0.0.0/0/5555:5555':
    *          => $auth_octavia,
    group      => 'lb-health-mgr-sec-grp',
    project    => 'service',
    protocol   => 'udp',
    port_range => '5555:5555',
    require    => Openstack::User['octavia'],
  }

  $octavia_dhclient_dir = '/etc/dhcp/octavia'
  $octavia_dhclient_conf = "${octavia_dhclient_dir}/dhclient.conf"

  if $manage_dhcp_directory {
    file { '/etc/dhcp':
      ensure => directory,
    }
  }

  file { '/etc/dhcp/octavia':
    ensure => directory,
  }

  file { $octavia_dhclient_conf:
    source => 'puppet:///modules/openstack/octavia/dhclient.conf'
  }

  openstack_network { 'lb-mgmt-net':
    *      => $auth_octavia,
  }

  openstack_subnet { 'lb-mgmt-subnet':
    *                     => $auth_octavia,
    network               => 'lb-mgmt-net',
    subnet_range          => $mgmt_subnet,
    allocation_pool_start => $mgmt_subnet_start,
    allocation_pool_end   => $mgmt_subnet_end,
    require               => Openstack_network['lb-mgmt-net']
  }

  $mgmt_port_name = 'octavia-health-manager-listen-port'

  openstack_port { $mgmt_port_name:
    *              => $auth_octavia,
    port_security  => true,
    security_group => 'lb-health-mgr-sec-grp',
    project        => 'service',
    device_owner   => 'Octavia:health-mgr',
    host_id        => $mgmt_port_host,
    network        => 'lb-mgmt-net',
    fixed_ips      => {
      'subnet_id'  => 'lb-mgmt-subnet',
      'ip_address' => $mgmt_port_ip,
    },
    require        => [
      Openstack_subnet['lb-mgmt-subnet'],
      Openstack_security_group['service/lb-health-mgr-sec-grp'],
    ]
  }

  if $facts['openstack'] {
    $mgmt_net = $facts['openstack']['networks']['lb-mgmt-net']
    if $mgmt_net {
      $netid = $mgmt_net['id']
      $brname = $netid[0,10]

      $mgmt_port_select = $facts['openstack']['ports'].filter |$port| {
        $port['name'] == $mgmt_port_name and $port['network_id'] == $netid
      }
      $mgmt_port = $mgmt_port_select[0]
      $mgmt_port_mac = $mgmt_port['mac_address']
    }
    else {
      $brname = undef
      $mgmt_port_mac = undef
    }
  }
}
