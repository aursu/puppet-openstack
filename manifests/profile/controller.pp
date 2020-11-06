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

  # Minimal deployment for Train
  # At a minimum, you need to install the following services. Install the
  # services in the order specified below:
  #
  # Identity service – [keystone installation for Train](https://docs.openstack.org/keystone/train/install/)
  include openstack::controller::keystone
  include openstack::controller::keystoneweb
  include openstack::controller::users

  # Image service – [glance installation for Train](https://docs.openstack.org/glance/train/install/)
  include openstack::controller::glance

  # Placement service – [placement installation for Train](https://docs.openstack.org/placement/train/install/)
  include openstack::controller::placement
  include openstack::controller::placementweb

  # Compute service – [nova installation for Train](https://docs.openstack.org/nova/train/install/)
  include openstack::controller::nova

  # Networking service – [neutron installation for Train](https://docs.openstack.org/neutron/train/install/)
  include openstack::controller::neutron

  # We advise to also install the following components after you have installed
  # the minimal deployment services:
  #
  # Dashboard – [horizon installation for Train](https://docs.openstack.org/horizon/train/install/)
  include openstack::controller::dashboard

  # Block Storage service – [cinder installation for Train](https://docs.openstack.org/cinder/train/install/index-rdo.html)
  include openstack::controller::cinder

  # https://docs.openstack.org/newton/install-guide-ubuntu/launch-instance-networks-provider.html
  include openstack::controller::networking

  # https://docs.openstack.org/heat/train/install/install-rdo.html
  include openstack::controller::heat

  # openstack::cinder::storage provides storage tools
  # lvm2, device-mapper-persistent-data and targetcli
  if $manage_docker
    and $openstack::controller::cinder::cinder_storage
    and $openstack::octavia_build_image {
      # therefore disable prerequired_packages which are storage tools as well
      class { 'dockerinstall':
        prerequired_packages => [],
      }
  }

  # https://docs.openstack.org/octavia/latest/install/install.html
  include openstack::controller::octavia

  # TODO: [backup service](https://docs.openstack.org/cinder/train/install/cinder-backup-install-rdo.html)
  # TODO: [Object storage](https://docs.openstack.org/swift/latest/install/)
}
