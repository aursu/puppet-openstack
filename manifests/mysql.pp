# @summary Manage MySQL module exported resources
#
# Contain collectors for exported MySQL database, user and grant resources
#
# @example
#   include openstack::mysql
class openstack::mysql (
  String  $database_tag = $openstack::database_tag,
)
{

  if $::operatingsystem == 'Ubuntu' {
    # https://docs.openstack.org/install-guide/environment-sql-database-ubuntu.html
    package { 'python-pymysql':
      ensure  => 'present',
    }
  }
  elsif $::osfamily == 'RedHat' {
    # https://docs.openstack.org/install-guide/environment-sql-database-rdo.html
    package { 'python2-PyMySQL':
      ensure  => 'present',
    }
  }

  # databases
  Mysql_database <<| tag == $database_tag |>>

  # database users
  Mysql_user <<| tag == $database_tag |>>

  # database grants
  Mysql_grant <<| tag == $database_tag |>>
}
