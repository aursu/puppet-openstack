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
    $project_dir = "${basedir}/${project}"

    file { $project_dir:
      ensure => directory,
    }

    # Docker context for Amphora image build
    archive { '/tmp/amphora.tar.gz':
      source       => 'puppet:///modules/openstack/build/amphora.tar.gz',
      extract      => true,
      extract_path => $project_dir,
      creates      => "${project_dir}/Dockerfile",
    }

    dockerinstall::webservice { $project:
      service_name   => 'amphora',
      docker_command => ['-o', '/root/octavia/diskimage-create/images/amphora-x64-haproxy.qcow2'],
      docker_image   => 'openstack/amphora:ubuntu-minimal',
      manage_image   => false,
      build_image    => true,
      restart        => 'no',
      docker_volume  => ['/var/lib/glance/images:/root/octavia/diskimage-create/images'],
      docker_build   => true,
      privileged     => true,
      before         => Openstack_image['amphora-x64-haproxy'],
      require        => Archive['/tmp/amphora.tar.gz'],
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
