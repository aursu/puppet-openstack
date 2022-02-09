# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include openstack::profile::controller
class openstack::profile::controller (
  Boolean $manage_docker = $openstack::manage_docker,
)
{
  include openstack
  include openstack::install

  # Identity service WEB
  include openstack::controller::keystoneweb

  # Placement service WEB
  include openstack::controller::placementweb

  # Cinder service WEB
  include openstack::controller::cinderweb

  # Dashboard – [horizon installation for Train](https://docs.openstack.org/horizon/xena/install/)
  include openstack::controller::dashboard

  # Minimal deployment for Train
  # At a minimum, you need to install the following services. Install the
  # services in the order specified below:
  #
  # Identity service – [keystone installation for Train](https://docs.openstack.org/keystone/xena/install/)
  include openstack::controller::keystone
  include openstack::controller::users

  # Image service – [glance installation for Train](https://docs.openstack.org/glance/xena/install/)
  include openstack::controller::glance

  # Placement service – [placement installation for Train](https://docs.openstack.org/placement/xena/install/)
  include openstack::controller::placement

  # Compute service – [nova installation for Train](https://docs.openstack.org/nova/xena/install/)
  include openstack::controller::nova

  # Networking service – [neutron installation for Train](https://docs.openstack.org/neutron/xena/install/)
  include openstack::controller::neutron

  # Block Storage service – [cinder installation for Train](https://docs.openstack.org/cinder/xena/install/index-rdo.html)
  include openstack::controller::cinder

  # https://docs.openstack.org/newton/install-guide-ubuntu/launch-instance-networks-provider.html
  include openstack::controller::networking

  # https://docs.openstack.org/heat/xena/install/install-rdo.html
  include openstack::controller::heat

  # https://docs.openstack.org/octavia/latest/install/install.html
  # TODO: complete
  # include openstack::controller::octavia

  # TODO: [backup service](https://docs.openstack.org/cinder/xena/install/cinder-backup-install-rdo.html)
  # TODO: [Object storage](https://docs.openstack.org/swift/latest/install/)

  # Services
  # systemctl restart neutron-linuxbridge-agent.service neutron-metadata-agent.service neutron-l3-agent.service neutron-server.service neutron-dhcp-agent.service
  # systemctl restart openstack-cinder-scheduler.service openstack-cinder-api.service openstack-cinder-volume.service
  # systemctl restart openstack-heat-engine.service openstack-heat-api.service openstack-heat-api-cfn.service
  # systemctl restart openstack-nova-api.service openstack-nova-novncproxy.service openstack-nova-conductor.service openstack-nova-scheduler.service
  # systemctl restart openstack-glance-api.service

  Class['openstack::controller::keystoneweb']
    -> Class['apache::service']
    -> Class['openstack::controller::keystone']

  Class['openstack::controller::keystone'] -> Class['openstack::controller::users']
  Class['openstack::controller::keystone'] -> Class['openstack::controller::glance']
  Class['openstack::controller::keystone'] -> Class['openstack::controller::placement']
  Class['openstack::controller::keystone'] -> Class['openstack::controller::nova']
  Class['openstack::controller::keystone'] -> Class['openstack::controller::neutron']
  Class['openstack::controller::keystone'] -> Class['openstack::controller::cinder']
  Class['openstack::controller::keystone'] -> Class['openstack::controller::heat']
  Class['openstack::controller::keystone'] -> Class['openstack::controller::octavia']

  Class['openstack::controller::neutron'] -> Class['openstack::controller::networking']
  Class['openstack::controller::neutron'] -> Class['openstack::controller::octavia']
}
