# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack
class openstack (
  Openstack::Release $cycle,
  String  $database_tag,
  String  $rabbitmq_user,
  Optional[String]  $rabbit_pass,
){
}
