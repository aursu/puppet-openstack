# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::rabbitmq
class openstack::rabbitmq (
  String  $rabbitmq_user = $openstack::rabbitmq_user,
  String  $rabbit_pass   = $openstack::rabbit_pass,
)
{
  # https://docs.openstack.org/install-guide/environment-messaging-rdo.html
  rabbitmq_user { $rabbitmq_user:
      ensure   => present,
      password => $rabbit_pass,
      require  => Class['rabbitmq'],
  }

  rabbitmq_user_permissions { "${rabbitmq_user}@/":
      configure_permission => '.*',
      read_permission      => '.*',
      write_permission     => '.*',
      require              => Rabbitmq_user[$rabbitmq_user],
  }
}
