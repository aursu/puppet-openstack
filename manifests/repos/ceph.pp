# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::repos::ceph
class openstack::repos::ceph (
  Enum['octopus', 'pacific']
          $release = 'pacific',
)
{
  # https://docs.ceph.com/en/latest/install/get-packages/
  case $facts['os']['family'] {
    'Debian': {
      apt::key { 'ceph.release':
        id     => '08B73419AC32B4E966C1A330E84AC2C0460F3994',
        source => 'https://download.ceph.com/keys/release.asc',
      }

      if $facts['os']['name'] == 'Ubuntu' {
        apt::source { 'ceph':
          location => "https://download.ceph.com/debian-${release}",
          release  => $facts['os']['distro']['codename'],
          repos    => 'main',
          require  => Apt::Key['ceph.release'],
          notify   => Class['openstack::repo'],
        }
      }
    }
    default: {
      $osmaj = $facts['os']['release']['major']
      yumrepo { 'Ceph':
        descr    => 'Ceph $basearch',
        baseurl  => "https://download.ceph.com/rpm-${release}/el${osmaj}/\$basearch",
        gpgkey   => 'https://download.ceph.com/keys/release.asc',
        enabled  => 1,
        gpgcheck => 1,
        target   => '/etc/yum.repos.d/ceph.repo',
        notify   => Class['openstack::repo'],
      }

      yumrepo { 'Ceph-noarch':
        descr    => 'Ceph noarch',
        baseurl  => "https://download.ceph.com/rpm-${release}/el${osmaj}/noarch",
        gpgkey   => 'https://download.ceph.com/keys/release.asc',
        enabled  => 1,
        gpgcheck => 1,
        target   => '/etc/yum.repos.d/ceph.repo',
        notify   => Class['openstack::repo'],
        require  => Yumrepo['Ceph'],
      }
    }
  }
}
