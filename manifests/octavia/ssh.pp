# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::octavia::ssh
class openstack::octavia::ssh {
  # Create a key pair for logging in to the amphora instance
  include openssh

  $octavia_ssh_dir = '/etc/octavia/.ssh'

  file { $octavia_ssh_dir:
    ensure => directory,
    mode   => '0700',
  }

  class { 'openssh::ssh_keygen':
    sshkey_generate_enable => true,
    sshkey_name            => 'Generated-by-Nova',
    sshkey_user            => 'root',
    sshkey_dir             => $octavia_ssh_dir,
  }

  openstack_keypair { 'octavia_ssh_key':
    private_key => "${octavia_ssh_dir}/id_rsa",
    require     => Class['openssh::ssh_keygen'],
  }
}
