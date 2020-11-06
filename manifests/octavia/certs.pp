# @summary Octavia Certificate Configuration
#
# Octavia Certificate Configuration
# See https://docs.openstack.org/octavia/latest/admin/guides/certificates.html
#
# @example
#   include openstack::octavia::certs
class openstack::octavia::certs (
  String $client_ca_pass = $openstack::octavia_client_ca_pass,
  String $server_ca_pass = $openstack::octavia_server_ca_pass,
)
{
  $certs_base = '/etc/octavia/certs'

  file { $certs_base:
    ensure => 'directory',
    mode   => '0700',
    owner  => 'octavia',
    group  => 'octavia',
  }

  openstack::octavia::ca { 'server_ca':
    pass       => $server_ca_pass,
    certs_base => $certs_base,
    subject    => {
      'country' => 'DE',
      'loc'     => 'Frankfurt',
      'org'     => 'OpenStack',
      'unit'    => 'Octavia',
      'com'     => 'ServerRootCA'
    }
  }

  openstack::octavia::ca { 'client_ca':
    pass       => $client_ca_pass,
    certs_base => $certs_base,
    subject    => {
      'country' => 'DE',
      'loc'     => 'Frankfurt',
      'org'     => 'OpenStack',
      'unit'    => 'Octavia',
      'com'     => 'ClientRootCA'
    }
  }

  openstack::octavia::cert { 'client':
    ca_pass    => $client_ca_pass,
    certs_base => $certs_base,
    ca_dir     => 'client_ca',
    subject    => {
      'com'     => 'OctaviaController',
      'unit'    => 'Octavia',
      'org'     => 'OpenStack',
      'loc'     => 'Frankfurt',
      'country' => 'DE',
    },
    bundle     => true,
  }

  file {
    default:
      owner   => 'octavia',
      group   => 'octavia',
      require => [
        Openstack::Octavia::Ca['server_ca'],
        Openstack::Octavia::Cert['client'],
      ]
    ;
    "${certs_base}/server_ca.key.pem":
      source => "file://${certs_base}/server_ca/private/ca.key.pem",
      mode   => '0700';
    "${certs_base}/server_ca.cert.pem":
      source => "file://${certs_base}/server_ca/certs/ca.cert.pem";
    "${certs_base}/client_ca.cert.pem":
      source => "file://${certs_base}/client_ca/certs/ca.cert.pem";
    "${certs_base}/client.cert-and-key.pem":
      source => "file://${certs_base}/client_ca/private/client.cert-and-key.pem",
      mode   => '0700';
  }
}
