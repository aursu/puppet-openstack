# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack
class openstack (
  Openstack::Release  $cycle,
  String              $database_tag,
  String              $rabbitmq_user,
  Optional[String]    $rabbit_pass,
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
  Stdlib::Host        $memcached_host,
  Integer             $memcached_port,
){
}
