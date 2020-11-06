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
          },
  Boolean $bundle      = false,
)
{
  $dir              = "${certs_base}/${ca_dir}"
  $conf             = "${dir}/openssl.cnf"
  $private_dir      = "${dir}/private"
  $csr_dir          = "${dir}/csr"
  $certs            = "${dir}/certs"
  $private_key      = "private/${cert_name}.key.pem"
  $private_key_path = "${dir}/private/${cert_name}.key.pem"
  $req              = "csr/${cert_name}.csr.pem"
  $certificate      = "certs/${cert_name}.cert.pem"
  $cert_bundle      = "private/${cert_name}.cert-and-key.pem"
  $subj_str         = openstack::cert_subject($subject)
  $subj_escape      = openstack::shell_escape($subj_str)

  if $pass {
    $pass_escape = openstack::shell_escape($pass)

    $private_key_command = "openssl genrsa -aes256 -out ${private_key} -passout pass:${pass_escape} 2048"
    $req_command = "openssl req -config ${conf} -new -sha256 -key ${private_key} -passin pass:${pass_escape} -subj ${subj_escape} -out ${req}" # lint:ignore:140chars
    $bundle_command = "openssl rsa -in ${private_key} -passin pass:${pass_escape} -out ${cert_bundle}"
  }
  else {
    $private_key_command = "openssl genrsa -out ${private_key} 2048"
    $req_command = "openssl req -config ${conf} -new -sha256 -key ${private_key} -subj ${subj_escape} -out ${req}" # lint:ignore:140chars
    $bundle_command = "openssl rsa -in ${private_key} -out ${cert_bundle}"
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
      creates => $private_key_path;
    # Create the CA certificate.
    $req:
      command => $req_command,
      unless  => "openssl req -noout -in ${req}",
      require => Exec[$private_key];
    # Create the CA certificate.
    $certificate:
      command => "openssl ca -config ${conf} -extensions usr_cert -days 3650 -notext -md sha256 -in ${req} -passin pass:${ca_pass_escape} -out ${certificate} -batch", # lint:ignore:140chars
      unless  => "openssl x509 -noout -in ${certificate}",
      require => Exec[$req];
  }

  if $bundle {
    exec {
      default:
        cwd  => $dir,
        path => '/usr/bin:/bin',
      ;
      # Initiate bundle
      $bundle_command:
        unless => "openssl rsa -noout -in ${cert_bundle}",
        before => Exec[$cert_bundle];
      $cert_bundle:
        command => "cat ${certificate} >> ${cert_bundle}",
        unless  => "openssl x509 -noout -in ${cert_bundle}";
    }
  }
}
