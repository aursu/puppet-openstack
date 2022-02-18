# @summary Cinder WEB service
#
# Cinder WEB service
#
# @example
#   include openstack::controller::cinderweb
class openstack::controller::cinderweb (
  Openstack::Release
          $cycle     = $openstack::cycle,
  String  $httpd_tag = $openstack::httpd_tag,
){
  include openstack::cinder::core

  if $facts['os']['family'] == 'Debian' {
    openstack::package { 'cinder-api':
      cycle   => $cycle,
      require => Openstack::Package['cinder-common'],
    }

    # remove config delivered by package cinder-api 
    file { '/etc/apache2/conf-available/cinder-wsgi.conf':
      ensure    => file,
      content   => '',
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
}
