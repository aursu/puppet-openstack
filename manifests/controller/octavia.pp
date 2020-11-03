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
  String  $octavia_pass    = $openstack::octavia_pass,
  String  $octavia_dbname  = $openstack::octavia_dbname,
  String  $octavia_dbuser  = $openstack::octavia_dbuser,
  String  $octavia_dbpass  = $openstack::octavia_dbpass,
  String  $database_tag    = $openstack::database_tag,
  String  $admin_pass      = $openstack::admin_pass,
)
{
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

  openstack_flavor { 'amphora':
    ensure            => present,
    disk              => 2,
    ram               => 1024,
    vcpus             => 1,
    visibility        => 'private',
    auth_username     => 'octavia',
    auth_password     => $octavia_pass,
    auth_project_name => 'service',
    require           => Openstack::User['octavia'],
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
}
