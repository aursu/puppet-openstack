# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::nova::core
class openstack::nova::core (
  String  $nova_pass                 = $openstack::nova_pass,
  Optional[String]
          $priv_key                  = $openstack::nova_priv_key,
  Optional[String]
          $pub_key                   = $openstack::nova_pub_key,
  Boolean $key_setup_root            = $openstack::nova_key_setup_root,
  String  $rabbitmq_user             = $openstack::rabbitmq_user,
  Stdlib::Host
          $rabbitmq_host             = $openstack::rabbitmq_host,
  Integer $rabbitmq_port             = $openstack::rabbitmq_port,
  String  $rabbit_pass               = $openstack::rabbit_pass,
  Stdlib::Host
          $controller_host           = $openstack::controller_host,
  Stdlib::Host
          $memcached_host            = $openstack::memcached_host,
  Integer $memcached_port            = $openstack::memcached_port,
  Stdlib::IP::Address
          $mgmt_interface_ip_address = $openstack::mgmt_interface_ip_address,
  String  $placement_pass            = $openstack::placement_pass,
  String  $sshkey_export_tag         = $openstack::sshkey_export_tag,
)
{
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
    shell      => '/bin/bash',
    managehome => true,
  }

  file { '/var/lib/nova':
    ensure  => directory,
    owner   => 'nova',
    group   => 'nova',
    mode    => '0711',
    require => User['nova'],
  }

  # SSH settings
  if $priv_key {
    openssh::priv_key { 'nova@compute':
      key_data   => $priv_key,
      user_name  =>  'nova',
      sshkey_dir => '/var/lib/nova/.ssh',
    }

    if $key_setup_root {
      openssh::priv_key { 'root@compute':
        key_data  => $priv_key,
        user_name => 'root',
      }
    }
  }

  if $pub_key {
    openssh::auth_key { 'nova@compute':
      sshkey            => $pub_key,
      sshkey_user       => 'nova',
      sshkey_target     => '/var/lib/nova/.ssh/authorized_keys',
      # export host key to avoid error 'Host key verification failed.'
      sshkey_export     => true,
      sshkey_export_tag => $sshkey_export_tag,
    }

    if $key_setup_root {
      openssh::auth_key { 'root@compute':
        sshkey            => $pub_key,
        sshkey_user       => 'root',
        # export host key to avoid error 'Host key verification failed.'
        sshkey_export     => true,
        sshkey_export_tag => $sshkey_export_tag,
      }
    }

    Sshkey <<| tag == "${sshkey_export_tag}_known_host" |>>
  }

  $conf_default = {
    ### enable only the compute and metadata APIs
    # [DEFAULT]
    # enabled_apis = osapi_compute,metadata
    'DEFAULT/enabled_apis' => 'osapi_compute,metadata',
    ### RabbitMQ message queue access
    # [DEFAULT]
    # transport_url = rabbit://openstack:RABBIT_PASS@controller:5672/
    'DEFAULT/transport_url' => "rabbit://${rabbitmq_user}:${rabbit_pass}@${rabbitmq_host}:${rabbitmq_port}/",
    ### Identity service access
    # [api]
    # auth_strategy = keystone
    'api/auth_strategy'                       => 'keystone',
    # [keystone_authtoken]
    # www_authenticate_uri = http://controller:5000/
    # auth_url = http://controller:5000/
    # memcached_servers = controller:11211
    # auth_type = password
    # project_domain_name = Default
    # user_domain_name = Default
    # project_name = service
    # username = nova
    # password = NOVA_PASS
    'keystone_authtoken/www_authenticate_uri' => "http://${controller_host}:5000/",
    'keystone_authtoken/auth_url'             => "http://${controller_host}:5000/",
    'keystone_authtoken/memcached_servers'    => "${memcached_host}:${memcached_port}",
    'keystone_authtoken/auth_type'            => 'password',
    'keystone_authtoken/project_domain_name'  => 'Default',
    'keystone_authtoken/user_domain_name'     => 'Default',
    'keystone_authtoken/project_name'         => 'service',
    'keystone_authtoken/username'             => 'nova',
    'keystone_authtoken/password'             => $nova_pass,
    # [DEFAULT]
    # my_ip = MANAGEMENT_INTERFACE_IP_ADDRESS
    'DEFAULT/my_ip'                           => $mgmt_interface_ip_address,
    ### location of the Image service API
    # [glance]
    # api_servers = http://controller:9292
    'glance/api_servers'                      => "http://${controller_host}:9292",
    ### the lock path
    # [oslo_concurrency]
    # lock_path = /var/lib/nova/tmp
    'oslo_concurrency/lock_path'              => '/var/lib/nova/tmp',
    # [placement]
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
    'placement/auth_url'                      => "http://${controller_host}:5000/v3",
    'placement/username'                      => 'placement',
    'placement/password'                      => $placement_pass,
  }

  openstack::config { '/etc/nova/nova.conf':
    content => $conf_default,
  }
}
