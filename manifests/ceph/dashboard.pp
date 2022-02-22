# @summary Ceph dashboard
#
# Ceph dashboard
#
# @example
#   include openstack::ceph::dashboard
class openstack::ceph::dashboard (
  Array[Stdlib::Fqdn]
          $server_name,
  Variant[String, Boolean]
          $cert_identity      = false,
  Boolean $manage_certificate = true,
)
{
  if $cert_identity =~ String {
    if $manage_certificate {
      tlsinfo::certpair { $cert_identity:
        identity => true,
      }
    }

    $certdata = tlsinfo::lookup($cert_identity)
    $ssl_cert = tlsinfo::certpath($certdata)
    $ssl_key  = tlsinfo::keypath($certdata)
  }
  else {
    $certdata = undef
    $ssl_cert = undef
    $ssl_key  = undef
  }

  if $ssl_cert and $ssl_key {
    exec { 'ceph-dashboard-set-ssl-certificate':
      command     => "ceph dashboard set-ssl-certificate -i ${ssl_cert}",
      path        => '/usr/bin:/usr/sbin:/bin:/sbin',
      onlyif      => "test -f ${ssl_cert}",
      refreshonly => true,
    }

    exec { 'ceph-dashboard-set-ssl-certificate-key':
      command     => "ceph dashboard set-ssl-certificate-key -i ${ssl_key}",
      path        => '/usr/bin:/usr/sbin:/bin:/sbin',
      onlyif      => "test -f ${ssl_key}",
      refreshonly => true,
    }

    if $cert_identity =~ String and $manage_certificate {
      Tlsinfo::Certpair[$cert_identity] ~> Exec['ceph-dashboard-set-ssl-certificate']
      Tlsinfo::Certpair[$cert_identity] ~> Exec['ceph-dashboard-set-ssl-certificate-key']
    }
  }
}
