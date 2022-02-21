# @summary Setup ceph config
#
# Setup Ceph config exported by Ceph manager host for Nova Compute
#
# @example
#   include openstack::ceph::ceph_client_nova
class openstack::ceph::ceph_client_nova {
  include openstack::ceph::ceph_client

  # mkdir -p /var/run/ceph/guests/ /var/log/qemu/
  # chown qemu:libvirt /var/run/ceph/guests /var/log/qemu/
  file { ['/var/run/ceph/guests', '/var/log/qemu']:
    ensure => directory,
    owner  => 'qemu',
    group  => 'libvirt',
  }

  if $facts['ceph_conf_exported'] {
    if $facts['ceph_conf_exported']['client'] {
      $client_section = $facts['ceph_conf_exported']['client']
    }
    else {
      $client_section = {}
    }

    # https://docs.ceph.com/en/latest/rbd/rbd-openstack/#configuring-nova
    file { '/etc/ceph/ceph.conf':
      ensure  => file,
      content => epp('openstack/ceph-conf.epp', {
        global => $facts['ceph_conf_exported']['global'],
        client => $client_section + {
          'rbd cache'                          => 'true',
          'rbd cache writethrough until flush' => 'true',
          'admin socket'                       => '/var/run/ceph/guests/$cluster-$type.$id.$pid.$cctid.asok',
          'log file'                           => '/var/log/qemu/qemu-guest-$pid.log',
          'rbd concurrent management ops'      => 20,
        },
      }),
    }
  }

  File <<| title == '/etc/ceph/client.cinder.secret.xml' |>>
}
