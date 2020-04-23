# @summary Add open security group into project
#
# Add open security group into project
#
# @example
#   openstack::net::secopen { 'project': }
define openstack::net::secopen (
  String  $project     = $name,
  String  $group_name   = 'open',
  Optional[String]
          $description = 'all ports open',
)
{
  openstack_security_group { "${project}/${group_name}":
    description => $description,
  }

  # [<project>/]<group>/<direction>/<proto>/<remote>/<range>'
  openstack_security_rule {
    default:
      project  => $project,
      group    => $group_name,
      protocol => 'tcp',
    ;
    "${project}/${group_name}/ingress/tcp/0.0.0.0/0/any":
      description => 'IPv4 TCP all ports',
    ;
    "${project}/${group_name}/ingress/udp/0.0.0.0/0/any":
      protocol    => 'udp',
      description => 'IPv4 UDP all ports',
    ;
    "${project}/${group_name}/ingress/tcp/::/0/any":
      ethertype   => ipv6,
      description => 'IPv6 TCP all ports',
    ;
    "${project}/${group_name}/ingress/udp/::/0/any":
      protocol    => 'udp',
      ethertype   => ipv6,
      description => 'IPv6 UDP all ports',
    ;
  }
}
