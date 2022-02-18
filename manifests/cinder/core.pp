# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::cinder::core
class openstack::cinder::core (
  Openstack::Release
          $cycle                     = $openstack::cycle,
  String  $cinder_dbname             = $openstack::cinder_dbname,
  String  $cinder_dbuser             = $openstack::cinder_dbuser,
  String  $cinder_dbpass             = $openstack::cinder_dbpass,
  String  $cinder_pass               = $openstack::cinder_pass,
  String  $rabbitmq_user             = $openstack::rabbitmq_user,
  String  $rabbit_pass               = $openstack::rabbit_pass,
  Stdlib::Host
          $memcached_host            = $openstack::memcached_host,
  Integer $memcached_port            = $openstack::memcached_port,
  Stdlib::IP::Address
          $mgmt_interface_ip_address = $openstack::mgmt_interface_ip_address,
  Optional[Stdlib::IP::Address]
          $storage_network           = $openstack::storage_network,
)
{
  if $facts['os']['family'] == 'RedHat' {
    openstack::package { 'openstack-cinder':
      cycle   => $cycle,
      configs => [
        '/etc/cinder/cinder.conf',
      ],
      before  => Openstack::Config['/etc/cinder/cinder.conf'],
    }
  }
  else {
    openstack::package { 'cinder-common':
      cycle   => $cycle,
      configs => [
        '/etc/cinder/cinder.conf',
      ],
      before  => Openstack::Config['/etc/cinder/cinder.conf'],
    }
  }

  # Identities
  group { 'cinder':
    ensure => present,
    system => true,
  }

  user { 'cinder':
    ensure  => present,
    system  => true,
    gid     => 'cinder',
    comment => 'OpenStack Cinder Daemons',
    home    => '/var/lib/cinder',
    shell   => '/sbin/nologin',
    require => Group['cinder']
  }

  file { '/var/lib/cinder':
    ensure  => directory,
    owner   => 'cinder',
    group   => 'cinder',
    mode    => '0711',
    require => User['cinder'],
  }

  openstack::config { '/etc/cinder/cinder.conf':
    content => {
      # [database]
      # connection = mysql+pymysql://cinder:CINDER_DBPASS@controller/cinder
      'database/connection'                     => "mysql+pymysql://${cinder_dbuser}:${cinder_dbpass}@controller/${cinder_dbname}",
      # [DEFAULT]
      # transport_url = rabbit://openstack:RABBIT_PASS@controller
      'DEFAULT/transport_url'                   => "rabbit://${rabbitmq_user}:${rabbit_pass}@controller",
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
      # username = cinder
      # password = CINDER_PASS
      'keystone_authtoken/www_authenticate_uri' => 'http://controller:5000',
      'keystone_authtoken/auth_url'             => 'http://controller:5000',
      'keystone_authtoken/memcached_servers'    => "${memcached_host}:${memcached_port}",
      'keystone_authtoken/auth_type'            => 'password',
      'keystone_authtoken/project_domain_name'  => 'default',
      'keystone_authtoken/user_domain_name'     => 'default',
      'keystone_authtoken/project_name'         => 'service',
      'keystone_authtoken/username'             => 'cinder',
      'keystone_authtoken/password'             => $cinder_pass,
      # [DEFAULT]
      # my_ip = MANAGEMENT_INTERFACE_IP_ADDRESS
      'DEFAULT/my_ip'                           => $mgmt_interface_ip_address,
      # [oslo_concurrency]
      # lock_path = /var/lib/cinder/tmp
      'oslo_concurrency/lock_path'              => '/var/lib/cinder/tmp',
    },
  }

  if $storage_network {
    $storage_interface_ip_address = networksetup::local_ips($storage_network)
    if $storage_interface_ip_address[0] {
      openstack::config { '/etc/cinder/cinder.conf/address':
        path    => '/etc/cinder/cinder.conf',
        content => {
          'DEFAULT/target_ip_address'          => $storage_interface_ip_address[0],
          'backend_defaults/target_ip_address' => $storage_interface_ip_address[0],
        },
        require => Openstack::Config['/etc/cinder/cinder.conf'],
      }
    }
  }
  else {
      openstack::config { '/etc/cinder/cinder.conf/address':
        path    => '/etc/cinder/cinder.conf',
        content => {
          'DEFAULT/target_ip_address'          => { value => '$my_ip', ensure => absent },
          'backend_defaults/target_ip_address' => { value => '$my_ip', ensure => absent },
        },
        require => Openstack::Config['/etc/cinder/cinder.conf'],
      }
  }
}
