# @summary Install and configure the Load-balancer service, code-named Octavia, on the controller nod
#
# Octavia is an open source, operator-scale load balancing solution designed to work with OpenStack
# https://docs.openstack.org/octavia/latest/install/install.html
#
# @example
#   include openstack::controller::octavia
class openstack::controller::octavia (
  Openstack::Release
          $cycle          = $openstack::cycle,
  String  $octavia_pass   = $openstack::octavia_pass,
  String  $octavia_dbname = $openstack::octavia_dbname,
  String  $octavia_dbuser = $openstack::octavia_dbuser,
  String  $octavia_dbpass = $openstack::octavia_dbpass,
  String  $database_tag   = $openstack::database_tag,
  String  $admin_pass     = $openstack::admin_pass,
)
{
  include openstack::octavia::certs

  class { 'openstack::octavia::amphora':
    octavia_pass => $octavia_pass,
  }

  file { '/etc/octavia':
    ensure => 'directory',
  }

  openstack::database { $octavia_dbname:
    dbuser       => $octavia_dbuser,
    dbpass       => $octavia_dbpass,
    database_tag => $database_tag,
  }

  openstack::user { 'octavia':
    role         => 'admin',
    project      => 'service',
    user_pass    => $octavia_pass,
    setup_openrc => true,
    require      => Openstack::Project['service'],
  }

  openstack::service { 'octavia':
    service     => 'load-balancer',
    description => 'OpenStack Octavia',
    endpoint    => {
      public   => 'http://controller:9876',
      internal => 'http://controller:9876',
      admin    => 'http://controller:9876',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['octavia'],
  }

  $auth_octavia = {
    auth_username     => 'octavia',
    auth_password     => $octavia_pass,
    auth_project_name => 'service',
  }

  openstack_flavor { 'amphora':
    ensure     => present,
    disk       => 2,
    ram        => 1024,
    vcpus      => 1,
    visibility => 'private',
    require    => Openstack::User['octavia'],
    *          => $auth_octavia,
  }

  openstack::package {
    default:
      cycle   => $cycle,
    ;
    'openstack-octavia-api':
      configs       => [
        '/etc/octavia/octavia.conf',
      ],
      notifyconfigs => false,
    ;
    'openstack-octavia-health-manager': ;
    'openstack-octavia-housekeeping': ;
    'openstack-octavia-worker': ;
    'python2-octavia': ;
    'python2-octaviaclient': ;
  }

  # Identities
  group { 'octavia':
    ensure => present,
    system => true,
  }

  user { 'octavia':
    ensure     => present,
    system     => true,
    gid        => 'octavia',
    comment    => 'OpenStack Octavia',
    home       => '/var/lib/octavia',
    managehome => true,
    shell      => '/sbin/nologin',
    require    => Group['octavia'],
  }

  file { '/var/lib/octavia':
    ensure  => directory,
    owner   => 'octavia',
    group   => 'octavia',
    mode    => '0711',
    require => User['octavia'],
  }

  # Create security groups and their rules
  openstack_security_group {
    default:
      project => 'service',
      *       => $auth_octavia,
    ;
    'lb-mgmt-sec-grp': ;
    'lb-health-mgr-sec-grp': ;
  }

  openstack_security_rule {
    default:
      group    => 'lb-mgmt-sec-grp',
      project  => 'service',
      protocol => 'tcp',
      *        => $auth_octavia,
    ;
    'service/lb-mgmt-sec-grp/ingress/icmp/0.0.0.0/0/any':
      protocol   => 'icmp';
    'service/lb-mgmt-sec-grp/ingress/tcp/0.0.0.0/0/22:22':
      port_range => '22:22';
    'service/lb-mgmt-sec-grp/ingress/tcp/0.0.0.0/0/9443:9443':
      port_range => '9443:9443';
  }

  openstack_security_rule { 'service/lb-health-mgr-sec-grp/ingress/udp/0.0.0.0/0/5555:5555':
    group      => 'lb-health-mgr-sec-grp',
    project    => 'service',
    protocol   => 'udp',
    port_range => '5555:5555',
    *          => $auth_octavia,
  }
}
