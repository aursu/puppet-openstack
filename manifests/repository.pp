# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   openstack::repository { 'namevar': }
define openstack::repository (
  Openstack::Release $cycle = $title,
)
{
  include openstack::repo

  # https://releases.openstack.org
  $available_series = ['ocata', 'pike', 'queens', 'rocky', 'stein', 'train', 'ussuri', 'victoria']
  $eol_series = ['ocata', 'pike']

  if $cycle in $eol_series {
    file { '/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Cloud':
      ensure => file,
      source => file('openstack/RPM-GPG-KEY-CentOS-SIG-Cloud'),
    }

    yumrepo { "CentOS-OpenStack-${cycle}":
      descr    => "CentOS-7 - OpenStack ${cycle}",
      baseurl  => "http://vault.centos.org/7.6.1810/cloud/\$basearch/openstack-${cycle}/",
      gpgkey   => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Cloud',
      enabled  => 1,
      gpgcheck => 1,
      target   => "/etc/yum.repos.d/CentOS-OpenStack-${cycle}.repo",
      notify   => Class['openstack::repo'],
      require  => File['/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-Cloud'],
    }
  }
  else {
    $available_series.each | String $c | {
      $package_name = "centos-release-openstack-${c}"

      if $c == $cycle {
        $package_ensure = 'present'
      }
      else {
        $package_ensure = 'absent'

        # manually created repos
        file { "/etc/yum.repos.d/CentOS-OpenStack-${c}.repo":
          ensure => absent,
        }
      }

      package { $package_name:
        ensure => $package_ensure,
        notify => Class['openstack::repo'],
      }
    }
  }
}
