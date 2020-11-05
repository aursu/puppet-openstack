# @summary Client certificate for Ocatvia
#
# Client certificate for Ocatvia
#
# @example
#   openstack::octavia::cert { 'namevar': }
define openstack::octavia::cert (
  String  $ca_pass,
  String  $cert_name   = $name,
  String  $ca_dir      = 'client_ca',
  Stdlib::Unixpath
          $certs_base  = '/etc/octavia/certs',
  Optional[String]
          $pass        = undef,
  Openstack::CertName
          $subject     = {
            'com'     => 'OctaviaController',
            'unit'    => 'Octavia',
            'org'     => 'OpenStack',
            'country' => 'DE',
          }
)
{
  $dir         = "${certs_base}/${ca_dir}"
  $conf        = "${dir}/openssl.cnf"
  $private_dir = "${dir}/private"
  $csr_dir     = "${dir}/csr"
  $certs       = "${dir}/certs"
  $private_key = "${dir}/private/${cert_name}.key.pem"
  $req         = "${dir}/csr/${cert_name}.csr.pem"
  $certificate = "${dir}/certs/${cert_name}.cert.pem"
  $subj_str    = openstack::cert_subject($subject)
  $subj_escape = openstack::shell_escape($subj_str)

  if $pass {
    $pass_escape = openstack::shell_escape($pass)
    $private_key_command = "openssl genrsa -aes256 -out private/${cert_name}.key.pem -passout pass:${pass_escape} 2048"
    $req_command = "openssl req -config ${conf} -new -sha256 -key private/${cert_name}.key.pem -passin pass:${pass_escape} -subj ${subj_escape} -out csr/${cert_name}.csr.pem" # lint:ignore:140chars
  }
  else {
    $private_key_command = "openssl genrsa -out private/${cert_name}.key.pem 2048"
    $req_command = "openssl req -config ${conf} -new -sha256 -key private/${cert_name}.key.pem -subj ${subj_escape} -out csr/${cert_name}.csr.pem" # lint:ignore:140chars
  }

  $ca_pass_escape = openstack::shell_escape($ca_pass)

  exec {
    default:
      cwd     => $dir,
      path    => '/usr/bin:/bin',
      require => Openstack::Octavia::Ca[$ca_dir]
    ;
    # Create the CA key.
    $private_key:
      command => $private_key_command,
      creates => $private_key,
    ;
    # Create the CA certificate.
    $req:
      command => $req_command,
      creates => $req,
      require => [
        Exec[$private_key],
      ],
    ;
    # Create the CA certificate.
    $certificate:
      command => "openssl ca -config ${conf} -extensions usr_cert -days 3650 -notext -md sha256 -in csr/${cert_name}.csr.pem -passin pass:${ca_pass_escape} -out certs/${cert_name}.cert.pem", # lint:ignore:140chars
      creates => $certificate,
      require => [
        Exec[$req],
      ],
    ;
  }
}
