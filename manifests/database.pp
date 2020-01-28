# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::database { 'namevar': }
define openstack::database (
  String  $dbuser,
  String  $dbpass,
  String  $database_tag,
  String  $dbname     = $name,
  Boolean $usercreate = true,
  Boolean $localhost  = true,
  Boolean $anyhost    = true,
  Boolean $exported   = true,
)
{
  # localhost is default access host
  if $localhost and $anyhost {
    $hosts = ['localhost', '%']
  }
  elsif $anyhost {
    $hosts = ['%']
  }
  else {
    $hosts = ['localhost']
  }

  # MySQL data
  if $exported {
    @@mysql_database { $dbname:
      ensure   => present,
      provider => 'mysql',
      tag      => $database_tag,
    }
  }
  else {
    mysql_database { $dbname:
      ensure   => present,
      provider => 'mysql',
    }
  }

  if $usercreate {
    $hosts.each | String $dbhost | {
      if $exported {
        @@mysql_user { "${dbuser}@${dbhost}":
          ensure        => present,
          password_hash => mysql_password($dbpass),
          tag           => $database_tag,
        }
      }
      else {
        mysql_user { "${dbuser}@${dbhost}":
          ensure        => present,
          password_hash => mysql_password($dbpass),
        }
      }
    }
  }

  $hosts.each | String $dbhost | {
    if $exported {
      @@mysql_grant { "${dbuser}@${dbhost}/${dbname}.*":
        ensure     => present,
        privileges => ['ALL'],
        table      => "${dbname}.*",
        user       => "${dbuser}@${dbhost}",
        require    => [
          Mysql_database[$dbname],
          Mysql_user["${dbuser}@${dbhost}"],
        ],
        tag        => $database_tag,
      }
    }
    else {
      mysql_grant { "${dbuser}@${dbhost}/${dbname}.*":
        ensure     => present,
        privileges => ['ALL'],
        table      => "${dbname}.*",
        user       => "${dbuser}@${dbhost}",
        require    => [
          Mysql_database[$dbname],
          Mysql_user["${dbuser}@${dbhost}"],
        ],
      }
    }
  }
}
