# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::glance
class openstack::controller::glance (
  Openstack::Release
          $cycle          = $openstack::cycle,
  String  $glance_pass    = $openstack::glance_pass,
  String  $glance_dbname  = $openstack::glance_dbname,
  String  $glance_dbuser  = $openstack::glance_dbuser,
  String  $glance_dbpass  = $openstack::glance_dbpass,
  String  $database_tag   = $openstack::database_tag,
  String  $admin_pass     = $openstack::admin_pass,
  Stdlib::Host
          $memcached_host = $openstack::memcached_host,
  Integer $memcached_port = $openstack::memcached_port,
  Boolean $ceph_storage   = $openstack::ceph_storage,
)
{
  include openstack::glance::core
  $filesystem_store_datadir = $openstack::glance::core::filesystem_store_datadir

  # https://docs.openstack.org/glance/train/install/install-rdo.html
  # verification: https://docs.openstack.org/glance/train/install/verify.html
  openstack::database { $glance_dbname:
    dbuser       => $glance_dbuser,
    dbpass       => $glance_dbpass,
    database_tag => $database_tag,
  }

  openstack::user { 'glance':
    role      => 'admin',
    project   => 'service',
    user_pass => $glance_pass,
    require   => Openstack::Project['service'],
  }

  openstack::service { 'glance':
    service     => 'image',
    description => 'OpenStack Image',
    endpoint    => {
      public   => 'http://controller:9292',
      internal => 'http://controller:9292',
      admin    => 'http://controller:9292',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['glance'],
  }

  # TODO: Per-Tenant Quotas
  # https://docs.openstack.org/glance/xena/admin/quotas.html

  $glance_package = $facts['os']['name'] ? {
    # https://docs.openstack.org/glance/xena/install/install-ubuntu.html#install-and-configure-components
    'Ubuntu' => 'glance',
    default  => 'openstack-glance',
  }

  openstack::package { $glance_package:
    cycle   => $cycle,
    configs => [
      '/etc/glance/glance-api.conf',
    ],
  }

  # reported bug: https://bugs.launchpad.net/glance/+bug/1672778
  exec { 'glance-db-sync':
    command     => 'glance-manage db_sync',
    path        => '/bin:/sbin:/usr/bin:/usr/sbin',
    cwd         => '/var/lib/glance',
    user        => 'glance',
    refreshonly => true,
    require     => [
      File['/var/lib/glance'],
      Openstack::Service['glance'],
    ],
  }

  $conf_default = {
    # [database]
    # connection = mysql+pymysql://glance:GLANCE_DBPASS@controller/glance
    'database/connection'                     => "mysql+pymysql://${glance_dbuser}:${glance_dbpass}@controller/${glance_dbname}",
    # [keystone_authtoken]
    # # ...
    # www_authenticate_uri  = http://controller:5000
    # auth_url = http://controller:5000
    # memcached_servers = controller:11211
    # auth_type = password
    # project_domain_name = Default
    # user_domain_name = Default
    # project_name = service
    # username = glance
    # password = GLANCE_PASS
    'keystone_authtoken/www_authenticate_uri' => 'http://controller:5000',
    'keystone_authtoken/auth_url'             => 'http://controller:5000',
    'keystone_authtoken/memcached_servers'    => "${memcached_host}:${memcached_port}",
    'keystone_authtoken/auth_type'            => 'password',
    'keystone_authtoken/project_domain_name'  => 'Default',
    'keystone_authtoken/user_domain_name'     => 'Default',
    'keystone_authtoken/project_name'         => 'service',
    'keystone_authtoken/username'             => 'glance',
    'keystone_authtoken/password'             => $glance_pass,

    # [paste_deploy]
    # flavor = keystone
    'paste_deploy/flavor'                     => 'keystone',
  }

  if $ceph_storage {
    $conf_default_storage = {
      # If you want to enable copy-on-write cloning of images, also add under the [DEFAULT] section
      'DEFAULT/show_image_direct_url' => 'true',
    }

    $glance_store_default = {
      # [glance_store]
      # stores = rbd
      # default_store = rbd
      # rbd_store_pool = images
      # rbd_store_user = glance
      # rbd_store_ceph_conf = /etc/ceph/ceph.conf
      # rbd_store_chunk_size = 8
      'glance_store/stores'               => 'rbd',
      'glance_store/default_store'        => 'rbd',
      'glance_store/rbd_store_pool'       => 'images',
      'glance_store/rbd_store_user'       => 'glance',
      'glance_store/rbd_store_ceph_conf'  => '/etc/ceph/ceph.conf',
      'glance_store/rbd_store_chunk_size' => 8,
    }
  }
  else {
    $conf_default_storage = {}

    $glance_store_default = {
      # [glance_store]
      # # ...
      # stores = file,http
      # default_store = file
      # filesystem_store_datadir = /var/lib/glance/images/
      'glance_store/default_store'            => 'file',
      'glance_store/filesystem_store_datadir' => $filesystem_store_datadir,
      'glance_store/stores'                   => 'file,http',
    }
  }

  # https://docs.openstack.org/glance/latest/configuration/configuring.html#configuring-glance-storage-backends

  openstack::config { '/etc/glance/glance-api.conf':
    content => $conf_default + $conf_default_storage + $glance_store_default,
    require => Openstack::Package[$glance_package],
    notify  => Exec['glance-db-sync'],
  }

  $glance_service = $facts['os']['name'] ? {
    # https://docs.openstack.org/keystone/xena/install/keystone-install-ubuntu.html
    'Ubuntu' => 'glance-api',
    default  => 'openstack-glance-api',
  }

  service { $glance_service:
    ensure  => running,
    enable  => true,
    require => Exec['glance-db-sync'],
  }

  # Ceph
  # On the glance-api node, you will need the Python bindings for librbd
  if $ceph_storage {
    include openstack::ceph::ceph_client
    include openstack::ceph::bindings

    Class['openstack::ceph::bindings'] -> Service[$glance_service]

    File <<| title == '/etc/ceph/ceph.client.glance.keyring' |>>
  }

  Mysql_database <| title == $glance_dbname |> ~> Exec['glance-db-sync']
}
