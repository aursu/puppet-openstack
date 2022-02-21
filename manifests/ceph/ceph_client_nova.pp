# @summary Setup ceph config
#
# Setup Ceph config exported by Ceph manager host for Nova Compute
#
# @example
#   include openstack::ceph::ceph_client_nova
class openstack::ceph::ceph_client_nova (
  String  $rbd_secret_uuid = $openstack::rbd_secret_uuid,
)
{
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

  # Then, on the compute nodes, add the secret key to libvirt and remove the
  # temporary copy of the key:
  file { '/etc/ceph/client.cinder.secret.xml':
    ensure  => file,
    content => epp('openstack/libvirt-secret.epp', {
      rbd_secret_uuid => $rbd_secret_uuid,
    }),
  }

  exec { 'virsh-client-cinder-secret':
    command => 'virsh secret-define --file /etc/ceph/client.cinder.secret.xml',
    path    => '/usr/bin:/usr/sbin:/bin:/sbin',
    unless  => "virsh secret-dumpxml ${rbd_secret_uuid}",
    require => File['/etc/ceph/client.cinder.secret.xml']
  }

  $cinder_key = $facts['ceph_client_cinder_key_exported']
  if $cinder_key {
    exec { "virsh secret-set-value --secret ${rbd_secret_uuid} --base64 ${cinder_key}":
      path    => '/usr/bin:/usr/sbin:/bin:/sbin',
      onlyif  => "virsh secret-dumpxml ${rbd_secret_uuid}",
      unless  => "virsh secret-get-value ${rbd_secret_uuid}",
      require => Exec['virsh-client-cinder-secret'],
    }
  }
}
