# @summary Apache configuration for OpenStack controller
#
# Apache configuration for OpenStack controller
#
# @example
#   include openstack::controller::httpd
class openstack::controller::httpd (
  String  $servername               = 'controller',
  Optional[String]
          $httpd_tag                = $openstack::httpd_tag,
  # Debian/Ubuntu specific
  Boolean $disable_vhost_enable_dir = true,
)
{
  include apache::params

  if $disable_vhost_enable_dir {
    # puppetlabs/apache module does not have types definitions
    $vhost_enable_dir = false
    $vhost_dir        = $apache::params::confd_dir
  }
  else {
    $vhost_enable_dir = $apache::params::vhost_enable_dir
    $vhost_dir        = $apache::params::vhost_dir
  }

  if $facts['os']['name'] == 'Ubuntu' and $facts['os']['release']['major'] in ['18.04', '20.04'] {
    $mod_wsgi_package = 'libapache2-mod-wsgi-py3'
    $mod_wsgi_path    = 'mod_wsgi.so'
  }
  else {
    $mod_wsgi_package = undef
    $mod_wsgi_path    = undef
  }

  if $facts['os']['family'] == 'RedHat' {
    exec { 'mkdir -p /etc/httpd/conf':
      creates => '/etc/httpd/conf',
      path    => '/bin:/usr/bin',
    }

    -> file { '/etc/httpd/modules':
      ensure => 'link',
      target => '../../usr/lib64/httpd/modules',
      before => Class['Apache'],
    }

    -> file { '/etc/httpd/run':
      ensure => 'link',
      target => '/run/httpd',
    }
  }

  if $facts['os']['family'] == 'Debian' {
    exec { 'mkdir -p /etc/apache2':
      creates => '/etc/apache2',
      path    => '/bin:/usr/bin',
    }

    -> file { '/etc/apache2/run':
      ensure => 'link',
      target => '/run/apache2',
    }
  }

  class { 'apache':
    apache_version         => '2.4',
    mpm_module             => false,
    default_mods           => [],
    use_systemd            => true,
    default_vhost          => false,
    default_ssl_vhost      => false,
    server_signature       => 'Off',
    trace_enable           => 'Off',
    servername             => $servername,
    timeout                => 60,
    keepalive              => 'On',
    max_keepalive_requests => 100,
    keepalive_timeout      => 5,
    root_directory_secured => true,
    docroot                => '/var/www/html',
    default_charset        => 'UTF-8',
    conf_template          => 'openstack/httpd/httpd.conf.erb',
    mime_types_additional  => undef,
    service_restart        => true,
    log_formats            => {
      'cinder_combined' => '%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\" %D(us)',
    },
    vhost_enable_dir       => $vhost_enable_dir,
    vhost_dir              => $vhost_dir,
  }

  class { 'apache::mod::prefork':
    startservers        => '5',
    minspareservers     => '5',
    maxspareservers     => '10',
    serverlimit         => '256',
    maxclients          => '256',
    maxrequestsperchild => '0',
    notify              => Class['Apache::Service'],
  }

  apache::listen { '80':
    notify => Class['Apache::Service'],
  }

  # apache::mod::mime included by SSL module
  class { 'apache::mod::ssl':
    ssl_compression            => false,
    ssl_cipher                 => 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384', # lint:ignore:140chars
    ssl_protocol               => [ 'all', '-SSLv3', '-TLSv1', '-TLSv1.1' ],
    ssl_random_seed_bytes      => '1024',
    ssl_mutex                  => 'default',
    ssl_stapling               => true,
    ssl_stapling_return_errors => false,
    notify                     => Class['Apache::Service'],
  }

  class { 'apache::mod::dir':
    indexes => [ 'index.html' ],
    notify  => Class['Apache::Service'],
  }

  class { 'apache::mod::mime_magic':
    magic_file => 'conf/magic',
    notify     => Class['Apache::Service'],
  }

  class { 'apache::mod::proxy':
    proxy_via => 'Off',
    notify    => Class['Apache::Service'],
  }

  class { 'apache::mod::wsgi':
    wsgi_socket_prefix => 'run/wsgi',
    package_name       => $mod_wsgi_package,
    mod_path           => $mod_wsgi_path,
    notify             => Class['Apache::Service'],
  }

  include apache::mod::headers
  include apache::mod::proxy_http
  include apache::mod::rewrite
  include apache::mod::alias

  if $httpd_tag {
    # virtual hosts
    Apache::Vhost <<| tag == $httpd_tag |>>

    # custom configs
    Apache::Custom_config <<| tag == $httpd_tag |>>
  }
}
