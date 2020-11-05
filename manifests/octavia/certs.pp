# @summary Octavia Certificate Configuration
#
# Octavia Certificate Configuration
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
}
