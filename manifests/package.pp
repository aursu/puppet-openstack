# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::package { 'namevar': }
define openstack::package  (
    String  $cycle,
    String  $package_ensure = 'present',
    String  $package        = $name,
    Array[Stdlib::Unixpath]
            $configs        = [],
    Boolean $notifyconfigs  = true,
)
{
    package { $package:
      ensure  => $package_ensure,
      require => Openstack::Repository[$cycle],
    }

    $configs.each |$config| {
      $rpmnew = "${config}.rpmnew"

      file { $rpmnew:
        ensure  => absent,
        require => Package[$package]
      }

      exec {
        default:
          path        => '/bin:/usr/bin',
          refreshonly => true,
          before      => File[$rpmnew],
        ;
        "${config}/update":
          command => "mv ${rpmnew} ${config}",
          onlyif  => "test -f ${rpmnew}",
        ;
        "${config}/save":
          command   => "mv ${config} ${config}.rpmsave",
          onlyif    => "test -f ${rpmnew}",
          subscribe => Package[$package],
          notify    => Exec["${config}/update"],
        ;
      }

      if $notifyconfigs {
        Exec["${config}/update"] ~> Openstack::Config[$config]
      }
    }
}
