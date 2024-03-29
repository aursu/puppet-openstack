# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::placementweb
class openstack::controller::placementweb (
  Openstack::Release
          $cycle     = $openstack::cycle,
  String  $httpd_tag = $openstack::httpd_tag,
)
{
  include apache::params
  include openstack::placement::core
  $placement_package = $openstack::placement::core::placement_package

  if $facts['os']['family'] == 'RedHat' {
    $confd_dir = $::apache::params::confd_dir

    # RPM openstack-placement-api provides HTTPd config which must be cleaned up
    # 1)
    file { "${confd_dir}/00-placement-api.conf":
      ensure    => absent,
      subscribe => Openstack::Package[$placement_package],
    }

    # 2) in case if 1) does not work
    Openstack::Package[$placement_package] ~> File <| title == $confd_dir |>
  }

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
    priority                    => false,
    tag                         => $httpd_tag,
    notify                      => Class['apache::service'],
    require                     => [
      User['placement'],
      Openstack::Package[$placement_package],
    ],
  }

  apache::custom_config { 'wsgi-placement':
    content => template('openstack/wsgi-placement.conf.erb'),
    tag     => $httpd_tag,
    require => Apache::Vhost['placement-api'],
    notify  => Class['apache::service'],
  }
}
