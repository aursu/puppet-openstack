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
}
