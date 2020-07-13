# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::controller::heat
class openstack::controller::heat (
  String  $heat_dbname             = $openstack::heat_dbname,
  String  $heat_dbuser             = $openstack::heat_dbuser,
  String  $heat_dbpass             = $openstack::heat_dbpass,
  String  $database_tag            = $openstack::database_tag,
  String  $heat_pass               = $openstack::heat_pass,
  String  $admin_pass              = $openstack::admin_pass,
)
{
  openstack::database { $heat_dbname:
    dbuser       => $heat_dbuser,
    dbpass       => $heat_dbpass,
    database_tag => $database_tag,
  }

  openstack::user { 'heat':
    role      => 'admin',
    project   => 'service',
    user_pass => $heat_pass,
    require   => Openstack::Project['service'],
  }

  openstack::service { 'heat':
    service     => 'orchestration',
    description => 'Orchestration',
    endpoint    => {
      public   => 'http://controller:8004/v1/%(tenant_id)s',
      internal => 'http://controller:8004/v1/%(tenant_id)s',
      admin    => 'http://controller:8004/v1/%(tenant_id)s',
    },
    admin_pass  => $admin_pass,
    require     => Openstack::User['heat'],
  }

  openstack::service { 'heat-cfn':
    service     => 'cloudformation',
    description => 'Orchestration',
    endpoint    => {
      public   => 'http://controller:8000/v1',
      internal => 'http://controller:8000/v1',
      admin    => 'http://controller:8000/v1',
    },
    admin_pass  => $admin_pass,
    require     => [
      Openstack::User['heat'],
      Openstack::Service['heat'],
    ]
  }

  # openstack domain create --description "Stack projects and users" heat
  openstack_domain { 'heat':
    description => 'Stack projects and users',
  }
}
