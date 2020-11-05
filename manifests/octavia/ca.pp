# @summary CA certificate for Octavia
#
# CA certificate for Octavia
#
# @example
#   openstack::octavia::ca { 'namevar': }
define openstack::octavia::ca (
  String  $pass,
  String  $ca_dir      = $name,
  Stdlib::Unixpath
          $certs_base  = '/etc/octavia/certs',
  String  $ossl_source = 'puppet:///modules/openstack/octavia/certs/openssl.cnf',
  Openstack::CertName
          $subject     = {
            'com'     => 'CertAuthCA',
            'unit'    => ['Octavia', 'CA'],
            'org'     => 'OpenStack',
            'country' => 'DE',
          }
)
{
  $dir         = "${certs_base}/${ca_dir}"
  $conf        = "${dir}/openssl.cnf"
  $database    = "${dir}/index.txt"
  $serial      = "${dir}/serial"
  $private_dir = "${dir}/private"
  $private_key = "${dir}/private/ca.key.pem"
  $certs       = "${dir}/certs"
  $certificate = "${dir}/certs/ca.cert.pem"

  file { $conf:
    source => $ossl_source,
  }

  file {
    default:
      ensure => 'directory',
      mode   => '0751',
    ;
    $dir: ;
    $certs: ;
    "${dir}/crl": ;
    "${dir}/csr": ;
    "${dir}/newcerts": ;
    $private_dir:
      mode => '0700',
    ;
  }

  exec {
    default:
      cwd     => $dir,
      path    => '/usr/bin:/bin',
      require => File[$dir],
    ;
    $database:
      command => 'touch index.txt',
      creates => $database,
    ;
    $serial:
      command => 'echo 1000 > serial',
      creates => $serial,
    ;
  }

  $pass_escape = openstack::shell_escape($pass)

  $subj_str = openstack::cert_subject($subject)
  $subj_escape = openstack::shell_escape($subj_str)

  exec {
    default:
      cwd  => $dir,
      path => '/usr/bin:/bin',
    ;
    # Create the CA key.
    $private_key:
      command => "openssl genrsa -aes256 -out private/ca.key.pem -passout pass:${pass_escape} 4096",
      creates => $private_key,
      require => File[$private_dir],
    ;
    # Create the CA certificate.
    $certificate:
      command => "openssl req -config ${conf} -key private/ca.key.pem -passin pass:${pass_escape} -new -x509 -days 3650 -sha256 -extensions v3_ca -subj ${subj_escape} -out certs/ca.cert.pem", # lint:ignore:140chars
      creates => $certificate,
      require => [
        File[$certs],
        Exec[$private_key],
        File[$conf],
      ],
    ;
  }
}
