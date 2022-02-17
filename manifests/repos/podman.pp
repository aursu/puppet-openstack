# @summary Podman Kubic project repositories
#
# Podman Kubic project repositories
#
# @example
#   include openstack::repos::podman
class openstack::repos::podman {
  # https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cri-o
  $osname = $facts['os']['name']
  $osmaj  = $facts['os']['release']['major']

  if $osname == 'Ubuntu' and $osmaj in ['18.04', '20.04', '20.10', '21.04'] {
    $os = "x${osname}_${osmaj}"

    # https://github.com/cri-o/cri-o/blob/main/install.md#apt-based-operating-systems
    apt::source { 'devel:kubic:libcontainers:stable':
      comment  => 'packaged versions of Podman',
      location => "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${os}/",
      release  => '', # no release folder
      repos    => '/',
      key      => {
        id     => '2472D6D0D2F66AF87ABA8DA34D64390375060AA4',
        source => "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${os}/Release.key",
      },
      notify   => Class['openstack::repo'],
    }
  }
}
