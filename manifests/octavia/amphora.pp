# @summary  Building Octavia Amphora Images.
#
# Building Octavia Amphora Images.
# see https://docs.openstack.org/octavia/latest/admin/amphora-image-build.html
#
# @example
#   include openstack::octavia::amphora
class openstack::octavia::amphora (
  Boolean $build_image  = $openstack::octavia_build_image,
  String  $octavia_pass = $openstack::octavia_pass,
)
{
  include dockerinstall::params
  $basedir = $dockerinstall::params::compose_libdir

  if $build_image {
    include lsys::docker

    $project = 'octavia'

    # Docker context for Amphora image build
    file { 'amphora.tar.gz':
      ensure => file,
      path   => "${basedir}/${project}/amphora.tar.gz",
      source => 'puppet:///modules/openstack/build/amphora.tar.gz',
    }

    dockerinstall::webservice { $project:
      service_name   => 'amphora',
      docker_command => ['-o', '/root/octavia/diskimage-create/images/amphora-x64-haproxy.qcow2'],
      docker_image   => 'openstack/amphora:ubuntu-minimal',
      manage_image   => false,
      restart        => 'no',
      docker_volume  => ['/var/lib/glance/images:/root/octavia/diskimage-create/images'],
      docker_build   => true,
      docker_context => 'amphora.tar.gz',
      privileged     => true,
      before         => Openstack_image['amphora-x64-haproxy'],
    }
  }

  openstack_image { 'amphora-x64-haproxy':
    ensure            => present,
    file              => '/var/lib/glance/images/amphora-x64-haproxy.qcow2',
    visibility        => 'private',
    tags              => [ 'amphora' ],
    disk_format       => 'qcow2',
    container_format  => 'bare',
    auth_username     => 'octavia',
    auth_password     => $octavia_pass,
    auth_project_name => 'service',
  }
}
