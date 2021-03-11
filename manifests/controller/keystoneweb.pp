# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::keystoneweb
class openstack::controller::keystoneweb (
  Openstack::Release
          $cycle     = $openstack::cycle,
  String  $httpd_tag = $openstack::httpd_tag,
)
{
  # https://docs.openstack.org/keystone/train/install/keystone-install-rdo.html#configure-the-apache-http-server
  if openstack::cyclecmp($cycle, 'queens') < 0 {
    $keystone_wsgi_admin = true
  }
  else {
    $keystone_wsgi_admin = false
  }

  $keystone_web_data = {
    ensure                      => 'present',
    manage_docroot              => false,
    docroot                     => false,
    servername                  => '',
    limitreqbody                => 114688,
    wsgi_daemon_process_options => {
      'processes'    => '5',
      'threads'      => '1',
      'user'         => 'keystone',
      'group'        => 'keystone',
      'display-name' => '%{GROUP}'
    },
    wsgi_application_group      => '%{GLOBAL}',
    wsgi_pass_authorization     => 'On',
    error_log                   => true,
    error_log_file              => 'keystone.log',
    access_log_file             => 'keystone_access.log',
    access_log_format           => 'combined',
    directories                 => [
      {
        provider => 'directory',
        path     => '/usr/bin',
        require  => 'all granted',
      }
    ],
    error_log_format            => [ '%{cu}t %M' ],
    tag                         => $httpd_tag,
    require                     => [
      User['keystone'],
      Package['openstack-keystone'],
    ]
  }

  # exported resource required only for httpd on other host
  # @@apache::vhost { 'keystone-public':
  apache::vhost { 'keystone-public':
    port                => '5000',
    wsgi_daemon_process => 'keystone-public',
    wsgi_process_group  => 'keystone-public',
    wsgi_script_aliases => {
      '/' => '/usr/bin/keystone-wsgi-public',
    },
    notify              => Class['Apache::Service'],
    *                   => $keystone_web_data,
  }

  if $keystone_wsgi_admin {
    # exported resource required only for httpd on other host
    # @@apache::vhost { 'keystone-admin':
    apache::vhost { 'keystone-admin':
      port                => '35357',
      wsgi_daemon_process => 'keystone-admin',
      wsgi_process_group  => 'keystone-admin',
      wsgi_script_aliases => {
        '/' => '/usr/bin/keystone-wsgi-admin',
      },
      notify              => Class['Apache::Service'],
      *                   => $keystone_web_data,
    }
  }

  # exported resource required only for httpd on other host
  # @@apache::custom_config
  apache::custom_config { 'wsgi-keystone':
    content => template('openstack/wsgi-keystone.conf.erb'),
    tag     => $httpd_tag,
    notify  => Class['Apache::Service'],
  }
}
