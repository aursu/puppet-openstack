# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::cinder
class openstack::controller::cinder (
  String  $cinder_dbname             = $openstack::cinder_dbname,
  String  $cinder_dbuser             = $openstack::cinder_dbuser,
  String  $cinder_dbpass             = $openstack::cinder_dbpass,
  String  $database_tag              = $openstack::database_tag,
  String  $cinder_pass               = $openstack::cinder_pass,
  String  $admin_pass                = $openstack::admin_pass,
  Boolean $cinder_storage            = $openstack::cinder_storage,
)
{
  include openstack::cinder::core

  if $cinder_storage {
    include openstack::cinder::storage
  }

  openstack::database { $cinder_dbname:
    dbuser       => $cinder_dbuser,
    dbpass       => $cinder_dbpass,
    database_tag => $database_tag,
  }

  openstack::user { 'cinder':
    role       => 'admin',
    project    => 'service',
    user_pass  => $cinder_pass,
    admin_pass => $admin_pass,
    require    => Openstack::Project['service'],
  }

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

  openstack::service { 'cinderv3':
    service     => 'volumev3',
    description => 'OpenStack Block Storage',
    endpoint    => {
      public   => 'http://controller:8776/v3/%(project_id)s',
      internal => 'http://controller:8776/v3/%(project_id)s',
      admin    => 'http://controller:8776/v3/%(project_id)s',
    },
    admin_pass  => $admin_pass,
    require     => [
      Openstack::User['cinder'],
      Openstack::Service['cinderv2'],
    ]
  }

  # [cinder]
  # os_region_name = RegionOne
  openstack::config { '/etc/nova/nova.conf/cinder':
    path    => '/etc/nova/nova.conf',
    content => {
      'cinder/os_region_name' => 'RegionOne',
    },
    require => Openstack::Config['/etc/nova/nova.conf'],
    notify  => Service['openstack-nova-api'],
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

  service {
    default:
      ensure    => running,
      enable    => true,
      require   => File['/var/lib/cinder'],
      subscribe => [
        Openstack::Config['/etc/cinder/cinder.conf'],
        Exec['cinder-db-sync'],
      ],
    ;
    'openstack-cinder-api':
    ;
    'openstack-cinder-scheduler':
    ;
  }

  Mysql_database <| title == $cinder_dbname |> ~> Exec['cinder-db-sync']
}
