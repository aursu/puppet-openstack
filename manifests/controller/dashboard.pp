# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::dashboard
class openstack::controller::dashboard (
  Openstack::Release
          $cycle                = $openstack::cycle,
  Optional[Array[Stdlib::Host, 1]]
          $allowed_hosts        = $openstack::dashboard_allowed_hosts,
  String  $time_zone            = $openstack::dashboard_time_zone,
  Boolean $self_service_network = $openstack::self_service_network,
  Stdlib::Host
          $memcached_host       = $openstack::memcached_host,
  Integer $memcached_port       = $openstack::memcached_port,
  String  $httpd_tag            = $openstack::httpd_tag,
)
{
  include apache::params
  $confd_dir = $::apache::params::confd_dir

  # https://docs.djangoproject.com/en/dev/ref/settings/#allowed-hosts
  $allowed_hosts_list = $allowed_hosts ? {
    Array => "['${join($allowed_hosts, "','")}']",
    default => "['*']"
  }

  $dashboard_data = {
    'OPENSTACK_HOST'                         => "'controller'",
    'WEBROOT'                                => "'/dashboard/'",
    'ALLOWED_HOSTS'                          => $allowed_hosts_list,
    'SESSION_ENGINE'                         => "'django.contrib.sessions.backends.cache'",
    'CACHES'                                 => {
      value => @("EOT"),
        {
          'default': {
            'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
            'LOCATION': '${memcached_host}:${memcached_port}'
          }
        }
        |-EOT
      order_after => 'SESSION_ENGINE',
    },
    'OPENSTACK_KEYSTONE_URL'                 => {
      value       => '"http://%s/identity/v3" % OPENSTACK_HOST',
      order_after => 'OPENSTACK_HOST',
    },
    'OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT' => 'True',
    'OPENSTACK_API_VERSIONS'                 => @(EOT),
      {
          "identity": 3,
          "image": 2,
          "volume": 3
      }
      |-EOT
    'OPENSTACK_KEYSTONE_DEFAULT_DOMAIN'     => "'Default'",
    'OPENSTACK_KEYSTONE_DEFAULT_ROLE'       => "'member'",
    'TIME_ZONE'                             => "'${time_zone}'",
  }

  if $self_service_network {
    $dashboard_openstack_neutron_network = {}
  }
  else {
    if openstack::cyclecmp($cycle, 'wallaby') < 0 {
      $dashboard_openstack_neutron_network = {
        'OPENSTACK_NEUTRON_NETWORK'             => @(EOT),
          {
            'enable_auto_allocated_network': False,
            'enable_distributed_router': False,
            'enable_ha_router': False,
            'enable_ipv6': True,
            'enable_rbac_policy': True,
            'default_dns_nameservers': [],
            'supported_provider_types': ['*'],
            'segmentation_id_range': {},
            'extra_provider_types': {},
            'supported_vnic_types': ['*'],
            'physical_networks': [],
            'enable_router': False,
            'enable_quotas': False,
            'enable_lb': False,
            'enable_firewall': False,
            'enable_vpn': False,
            'enable_fip_topology_check': False,
          }
          |-EOT
      }
    }
    else {
      $dashboard_openstack_neutron_network = {
        'OPENSTACK_NEUTRON_NETWORK'             => @(EOT),
          {
            'enable_auto_allocated_network': False,
            'enable_distributed_router': False,
            'enable_ha_router': False,
            'enable_ipv6': True,
            'enable_rbac_policy': True,
            'default_dns_nameservers': [],
            'supported_provider_types': ['*'],
            'segmentation_id_range': {},
            'extra_provider_types': {},
            'supported_vnic_types': ['*'],
            'physical_networks': [],
            'enable_router': False,
            'enable_quotas': False,
            'enable_fip_topology_check': False,
          }
          |-EOT
      }
    }
  }

  openstack::package { 'openstack-dashboard':
    cycle         => $cycle,
    configs       => [
      '/etc/openstack-dashboard/local_settings',
    ],
    notifyconfigs => false,
  }

  openstack::djangoconfig { '/etc/openstack-dashboard/local_settings':
    content   => $dashboard_data + $dashboard_openstack_neutron_network,
    subscribe => Openstack::Package['openstack-dashboard'],
    notify    => Class['Apache::Service'],
  }

  if $allowed_hosts {
    $servername = $allowed_hosts[0]
    if size($allowed_hosts) > 1 {
        $serveraliases = $allowed_hosts[1,-1]
    } else {
        $serveraliases = undef
    }

    apache::vhost { 'openstack-dashboard':
      port                => '80',
      docroot             => false,
      servername          => $servername,
      serveraliases       => $serveraliases,
      error_log           => false,
      access_log          => false,
      wsgi_daemon_process => 'dashboard',
      wsgi_process_group  => 'dashboard',
      wsgi_script_aliases => {
        '/dashboard' => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi',
      },
      aliases             => [
        {
          alias => '/dashboard/static',
          path  => '/usr/share/openstack-dashboard/static',
        },
      ],
      directories         => [
        {
          provider       => 'directory',
          path           => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi',
          options        => [ 'All' ],
          allow_override => [ 'All' ],
          require        => 'all granted',
        },
        {
          provider       => 'directory',
          path           => '/usr/share/openstack-dashboard/static',
          options        => [ 'All' ],
          allow_override => [ 'All' ],
          require        => 'all granted',
        },
      ],
      tag                 => $httpd_tag,
      notify              => Class['Apache::Service'],
    }
  }

  apache::custom_config { 'openstack-dashboard':
    content => template('openstack/openstack-dashboard.conf.erb'),
    tag     => $httpd_tag,
    notify  => Class['Apache::Service'],
  }

  Package['openstack-dashboard'] ~> File <| title == $confd_dir |>
}
