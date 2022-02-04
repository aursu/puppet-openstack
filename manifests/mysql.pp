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
  if $::osfamily == 'RedHat' {
    # https://docs.openstack.org/install-guide/environment-sql-database-rdo.html
    $python_client = 'python2-PyMySQL'
  }
  elsif $::operatingsystem == 'Ubuntu' {
    # https://docs.openstack.org/install-guide/environment-sql-database-ubuntu.html
    $python_client = $facts['os']['release']['major'] ? {
      '20.04' => 'python3-pymysql',
      default => 'python-pymysql',
    }
  }

  package { $python_client:
    ensure  => 'present',
  }

  # databases
  Mysql_database <<| tag == $database_tag |>>

  # database users
  Mysql_user <<| tag == $database_tag |>>

  # database grants
  Mysql_grant <<| tag == $database_tag |>>
}
