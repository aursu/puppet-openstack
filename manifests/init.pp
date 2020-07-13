# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack
class openstack (
  Openstack::Release  $cycle,
  String              $database_tag,
  String              $rabbitmq_host,
  String              $rabbitmq_user,
  Integer             $rabbitmq_port,
  Optional[String]    $rabbit_pass,
  Stdlib::Host        $memcached_host,
  Integer             $memcached_port,
  Optional[Stdlib::IP::Address]
                      $mgmt_interface_ip_address,
  Boolean             $self_service_network,
  # Keystone
  String              $keystone_dbname,
  String              $keystone_dbuser,
  Optional[String]
                      $keystone_dbpass,
  Optional[String]    $admin_pass,
  # Glance
  String              $glance_dbname,
  String              $glance_dbuser,
  Optional[String]
                      $glance_dbpass,
  Optional[String]    $glance_pass,
  # Placement
  String              $placement_dbname,
  String              $placement_dbuser,
  Optional[String]
                      $placement_dbpass,
  Optional[String]    $placement_pass,
  # Nova (Compute)
  String              $nova_dbname,
  String              $nova_dbuser,
  Optional[String]    $nova_pass,
  Optional[String]    $nova_dbpass,
  # Neutron
  String              $neutron_dbname,
  String              $neutron_dbuser,
  Optional[String]    $neutron_dbpass,
  Optional[String]    $neutron_pass,
  Optional[String]    $metadata_secret,
  String              $provider_physical_network,
  Optional[Stdlib::IP::Address]
                      $provider_network_cidr,
  Optional[Stdlib::IP::Address]
                      $provider_network_gateway,
  Array[Stdlib::IP::Address]
                      $provider_network_dns,
  Optional[Stdlib::IP::Address]
                      $provider_network_start_ip,
  Optional[Stdlib::IP::Address]
                      $provider_network_end_ip,
  Optional[String]    $provider_interface_name,
  # Dashboard
  Optional[Array[Stdlib::Host]]
                      $dashboard_allowed_hosts,
  String              $dashboard_time_zone,
  # Cinder
  String              $cinder_dbname,
  String              $cinder_dbuser,
  Optional[String]    $cinder_dbpass,
  Optional[String]    $cinder_pass,
  Boolean             $cinder_storage,
  String              $cinder_volume_group,
  Optional[Array[String]]
                      $lvm_devices_filter,
  Optional[Array[Stdlib::Unixpath]]
                      $cinder_physical_volumes,
  # Heat
  String              $heat_dbname,
  String              $heat_dbuser,
  Optional[String]    $heat_dbpass,
  Optional[String]    $heat_pass,

  Stdlib::Host        $controller_host,
  String              $compute_tag,


){
  # setup OS limits for Ussuri release
  if $facts['os']['family'] == 'RedHat' and $facts['os']['release']['major'] in ['6', '7'] {
    if openstack::cyclecmp($cycle, 'ussuri') >= 0 {
      fail('Starting with the Ussuri release, you will need to use either CentOS8 or RHEL 8')
    }
  }
}
