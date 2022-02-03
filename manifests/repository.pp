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
  include openstack::params

  # https://releases.openstack.org
  $eol_series = ['ocata', 'pike']

  if $facts['os']['name'] == 'CentOS' {
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
      $maj = $facts['os']['release']['major']
      case $maj {
        '7': {
          $available_series = ['queens', 'rocky', 'stein', 'train']
        }
        '8': {
          if $openstack::params::centos_stream {
            $available_series = ['train', 'ussuri', 'victoria', 'wallaby', 'xena']
          }
          else {
            $available_series = ['train', 'ussuri', 'victoria']
          }
        }
        default: {
          # https://docs.openstack.org/install-guide/preface.html#operating-systems
          fail("Unsupported CentOS version ${maj}")
        }
      }

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
  elsif $facts['os']['name'] == 'Ubuntu' {
    include apt

    $maj = $facts['os']['release']['major']
    case $maj {
      '20.04': {
        $available_series = ['ussuri', 'victoria', 'wallaby', 'xena']
      }
      '18.04': {
        $available_series = ['queens', 'rocky', 'stein', 'train', 'ussuri']
      }
      default: {
        fail("Unsupported Ubuntu version ${maj}")
      }
    }

    $available_series.each | String $c | {
      $ppa_name = "cloud-archive:${c}"

      if $c == $cycle {
        $ppa_ensure = 'present'
      }
      else {
        $ppa_ensure = 'absent'
      }

      apt::ppa { $ppa_name:
        ensure => $ppa_ensure,
        notify => Class['openstack::repo'],
      }
    }
  }
}
