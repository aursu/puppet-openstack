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

  if $facts['os']['family'] == 'Debian' {
    $dashboard_config = '/etc/openstack-dashboard/local_settings.py'

    package { 'python2':
      ensure => 'present',
      before => Openstack::Djangoconfig[$dashboard_config],
    }
  }
  else {
    $dashboard_config = '/etc/openstack-dashboard/local_settings'
  }

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
    configs       => [ $dashboard_config ],
    notifyconfigs => false,
  }

  if openstack::cyclecmp($cycle, 'wallaby') < 0 {
    $wsgi_script = '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi'
    $wsgi_script_path = '/usr/share/openstack-dashboard/openstack_dashboard/wsgi'
  }
  else {
    $wsgi_script = '/usr/share/openstack-dashboard/openstack_dashboard/wsgi.py'
    $wsgi_script_path = '/usr/share/openstack-dashboard/openstack_dashboard'
  }

  if $facts['os']['family'] == 'Debian' {
    $static_content_path = '/var/lib/openstack-dashboard/static'

    $dashboard_web_data = {
      wsgi_daemon_process_options => {
        'processes'    => '3',
        'threads'      => '10',
        'user'         => 'horizon',
        'group'        => 'horizon',
        'display-name' => '%{GROUP}'
      },
      wsgi_script_aliases => {
        '/dashboard' => [$wsgi_script, 'process-group=horizon'],
      }
    }

    $wsgi_daemon_process_options =  {
      user         => 'horizon',
      group        => 'horizon',
      processes    => 3,
      threads      => 10,
      display-name => '%{GROUP}',
    }

    $wsgi_script_options = {
      process-group => 'horizon',
    }

    $wsgi_application_group = '%{GLOBAL}'

    file { '/etc/apache2/conf-available/openstack-dashboard.conf':
      ensure    => absent,
      subscribe => Openstack::Package['openstack-dashboard'],
    }
  }
  else {
    $static_content_path = '/usr/share/openstack-dashboard/static'

    $dashboard_web_data = {
      wsgi_script_aliases => {
        '/dashboard' => $wsgi_script,
      },
    }

    $wsgi_socket_prefix = 'run/wsgi'
  }

  openstack::djangoconfig { $dashboard_config:
    content   => $dashboard_data + $dashboard_openstack_neutron_network,
    subscribe => Openstack::Package['openstack-dashboard'],
    notify    => Class['apache::service'],
  }

  if $allowed_hosts {
    $servername = $allowed_hosts[0]
    if size($allowed_hosts) > 1 {
        $serveraliases = $allowed_hosts[1,-1]
    } else {
        $serveraliases = undef
    }

    apache::vhost { 'openstack-dashboard':
      *                      => $dashboard_web_data,
      port                   => '80',
      docroot                => false,
      servername             => $servername,
      serveraliases          => $serveraliases,
      error_log              => false,
      access_log             => false,
      wsgi_daemon_process    => 'dashboard',
      wsgi_process_group     => 'dashboard',
      wsgi_application_group => '%{GLOBAL}',
      aliases                => [
        {
          alias => '/static',
          path  => $static_content_path,
        },
        {
          alias => '/dashboard/static',
          path  => $static_content_path,
        }
      ],
      directories            => [
        {
          provider       => 'directory',
          path           => $wsgi_script_path,
          options        => [ 'All' ],
          allow_override => [ 'All' ],
          require        => 'all granted',
        },
        {
          provider       => 'directory',
          path           => $static_content_path,
          options        => [ 'All' ],
          allow_override => [ 'All' ],
          require        => 'all granted',
        },
      ],
      tag                    => $httpd_tag,
      notify                 => Class['apache::service'],
    }
  }

  apache::custom_config { 'openstack-dashboard':
    content => template('openstack/openstack-dashboard.conf.erb'),
    tag     => $httpd_tag,
    notify  => Class['apache::service'],
  }

  Package['openstack-dashboard'] ~> File <| title == $confd_dir |>
}
