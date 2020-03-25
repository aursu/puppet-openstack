# @summary A short summary of the purpose of this class
#
# compute node handles connectivity and security groups for instances
#
# @example
#   include openstack::compute::neutron
class openstack::compute::neutron (
  String  $neutron_pass              = $openstack::neutron_pass,
  Stdlib::Host
          $controller_host           = $openstack::controller_host,
){
  include openstack::neutron::core

  # [neutron]
  # auth_url = http://controller:5000
  # auth_type = password
  # project_domain_name = default
  # user_domain_name = default
  # region_name = RegionOne
  # project_name = service
  # username = neutron
  # password = NEUTRON_PASS
  openstack::config { '/etc/nova/nova.conf/neutron':
    path    => '/etc/nova/nova.conf',
    content => {
      'neutron/auth_url'            => "http://${controller_host}:5000",
      'neutron/auth_type'           => 'password',
      'neutron/project_domain_name' => 'default',
      'neutron/user_domain_name'    => 'default',
      'neutron/region_name'         => 'RegionOne',
      'neutron/project_name'        => 'service',
      'neutron/username'            => 'neutron',
      'neutron/password'            => $neutron_pass,
    },
    require => Openstack::Config['/etc/nova/nova.conf'],
    notify  => Service['openstack-nova-compute'],
  }
}
