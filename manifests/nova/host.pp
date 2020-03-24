# @summary Register new compute nodes
#
# When you add new compute nodes, you must run
#     nova-manage cell_v2 discover_hosts
# on the controller node to register those new compute nodes
#
# @example
#   openstack::nova::host { 'compute-01': }
define openstack::nova::host (
  String  $host_id = $name,
)
{
  exec { "nova-discover_hosts-${host_id}":
    command => 'nova-manage cell_v2 discover_hosts',
    unless  => "nova-manage host list | grep ${host_id}",
    path    => '/bin:/sbin:/usr/bin:/usr/sbin',
    cwd     => '/var/lib/nova',
    user    => 'nova',
    require => [
        File['/var/lib/nova'],
        Openstack::Config['/etc/nova/nova.conf'],
        Exec['nova-create-cell1']
    ]
  }
}
