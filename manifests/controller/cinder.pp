# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::cinder
class openstack::controller::cinder (
  Openstack::Release
          $cycle                     = $openstack::cycle,
  String  $cinder_dbname             = $openstack::cinder_dbname,
  String  $cinder_dbuser             = $openstack::cinder_dbuser,
  String  $cinder_dbpass             = $openstack::cinder_dbpass,
  String  $database_tag              = $openstack::database_tag,
  String  $cinder_pass               = $openstack::cinder_pass,
  String  $admin_pass                = $openstack::admin_pass,
  Boolean $cinder_storage            = $openstack::cinder_storage,
  String  $httpd_tag                 = $openstack::httpd_tag,
)
{
  # Notes:
  # 2021-03-18 13:22:55.765 727175 ERROR oslo_messaging.rpc.server cinder.exception.ImageTooBig:
  # Image a4bcdd42-caea-4037-bb76-7f79c367511a size exceeded available disk space: There is no space
  # on /var/lib/cinder/conversion to convert image. Requested: 107374182400, available: 44265283584.

  include openstack::cinder::core

  if $facts['os']['family'] == 'Debian' {
    $nova_service = 'nova-api'
    $cinder_scheduler_service = 'cinder-scheduler'

    openstack::package {
      default:
        cycle => $cycle,
      ;
      'cinder-api':
        configs => [
          '/etc/cinder/cinder.conf',
        ],
        before  => Openstack::Config['/etc/cinder/cinder.conf'],
      ;
      'cinder-scheduler': ;
    }

    # remove config delivered by package cinder-api 
    file { '/etc/apache2/conf-available/cinder-wsgi.conf':
      ensure    => 'absent',
      subscribe => Openstack::Package['cinder-api'],
    }

    apache::vhost { 'cinder-wsgi':
      ensure                      => 'present',
      port                        => '8776',
      wsgi_daemon_process         => 'cinder-wsgi',
      wsgi_process_group          => 'cinder-wsgi',
      wsgi_script_aliases         => {
        '/' => '/usr/bin/cinder-wsgi',
      },
      priority                    => false,
      manage_docroot              => false,
      docroot                     => false,
      servername                  => '',
      wsgi_daemon_process_options => {
        'processes'    => '5',
        'threads'      => '1',
        'user'         => 'cinder',
        'group'        => 'cinder',
        'display-name' => '%{GROUP}'
      },
      wsgi_application_group      => '%{GLOBAL}',
      wsgi_pass_authorization     => 'On',
      error_log                   => true,
      error_log_file              => 'cinder_error.log',
      access_log_file             => 'cinder.log',
      access_log_format           => 'cinder_combined',
      directories                 => [
        {
          provider => 'directory',
          path     => '/usr/bin',
          require  => 'all granted',
        }
      ],
      error_log_format            => [ '%{cu}t %M' ],
      tag                         => $httpd_tag,

      notify                      => Class['apache::service'],
      require                     => [
        User['cinder'],
        Openstack::Package['cinder-api'],
        File['/etc/apache2/conf-available/cinder-wsgi.conf'],
      ]
    }
  }
  else {
    $nova_service = 'openstack-nova-api'
    $cinder_scheduler_service = 'openstack-cinder-scheduler'

    service { 'openstack-cinder-api':
      ensure    => running,
      enable    => true,
      require   => File['/var/lib/cinder'],
      subscribe => [
        Openstack::Config['/etc/cinder/cinder.conf'],
        Exec['cinder-db-sync'],
      ],
    }
  }

  if $cinder_storage {
    include openstack::cinder::storage
  }

  openstack::database { $cinder_dbname:
    dbuser       => $cinder_dbuser,
    dbpass       => $cinder_dbpass,
    database_tag => $database_tag,
  }

  openstack::user { 'cinder':
    role      => 'admin',
    project   => 'service',
    user_pass => $cinder_pass,
    require   => Openstack::Project['service'],
  }

  # Beginning with the Xena release, the Block Storage services
  # require only one service entity.
  if openstack::cyclecmp($cycle, 'xena') < 0 {
    openstack::service { 'cinderv2':
      service     => 'volumev2',
      description => 'OpenStack Block Storage',
      endpoint    => {
        public   => 'http://controller:8776/v2/%(project_id)s',
        internal => 'http://controller:8776/v2/%(project_id)s',
        admin    => 'http://controller:8776/v2/%(project_id)s',
      },
      admin_pass  => $admin_pass,
      require     => Openstack::User['cinder'],
    }

    Openstack::Service['cinderv2'] -> Openstack::Service['cinderv3']
  }

  openstack::service { 'cinderv3':
    service     => 'volumev3',
    description => 'OpenStack Block Storage',
    endpoint    => {
      public   => 'http://controller:8776/v3/%(project_id)s',
      internal => 'http://controller:8776/v3/%(project_id)s',
      admin    => 'http://controller:8776/v3/%(project_id)s',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['cinder'],
  }

  # [cinder]
  # os_region_name = RegionOne
  openstack::config { '/etc/nova/nova.conf/cinder':
    path    => '/etc/nova/nova.conf',
    content => {
      'cinder/os_region_name' => 'RegionOne',
    },
    require => Openstack::Config['/etc/nova/nova.conf'],
    notify  => Service[$nova_service],
  }

  # su -s /bin/sh -c "cinder-manage db sync" cinder
  exec { 'cinder-db-sync':
    command     => 'cinder-manage db sync',
    path        => '/bin:/sbin:/usr/bin:/usr/sbin',
    cwd         => '/var/lib/cinder',
    user        => 'cinder',
    refreshonly => true,
    require     => [
      File['/var/lib/cinder'],
      Openstack::Service['cinderv3'],
    ],
    subscribe   => Openstack::Config['/etc/cinder/cinder.conf'],
  }

  service { $cinder_scheduler_service:
    ensure    => running,
    enable    => true,
    require   => File['/var/lib/cinder'],
    subscribe => [
      Openstack::Config['/etc/cinder/cinder.conf'],
      Exec['cinder-db-sync'],
    ],
  }

  Mysql_database <| title == $cinder_dbname |> ~> Exec['cinder-db-sync']
}
