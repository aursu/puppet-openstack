# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::placementweb
class openstack::controller::placementweb (
  Openstack::Release
          $cycle    = $openstack::cycle,
  String $httpd_tag = 'openstack',
)
{
  apache::vhost { 'placement-api':
    ensure                      => 'present',
    manage_docroot              => false,
    docroot                     => false,
    servername                  => '',
    port                        => '8778',
    wsgi_process_group          => 'placement-api',
    wsgi_application_group      => '%{GLOBAL}',
    wsgi_pass_authorization     => 'On',
    wsgi_daemon_process         => 'placement-api',
    wsgi_daemon_process_options => {
      'processes' => '3',
      'threads'   => '1',
      'user'      => 'placement',
      'group'     => 'placement',
    },
    wsgi_script_aliases         => {
      '/' => '/usr/bin/placement-api',
    },
    error_log                   => true,
    error_log_format            => [ '%M' ],
    error_log_file              => 'placement-api.log',
    access_log_file             => 'placement_access.log',
    access_log_format           => 'combined',
    directories                 => [
      {
        provider => 'directory',
        path     => '/usr/bin',
        require  => 'all granted',
      }
    ],
    tag                         => $httpd_tag,
    notify                      => Class['Apache::Service'],
    require                     => [
      User['placement'],
      Package['openstack-placement-api'],
    ],
  }

  apache::custom_config { 'wsgi-placement':
    content => template('openstack/wsgi-placement.conf.erb'),
    notify  => Class['Apache::Service'],
  }
}
