# @summary Cinder client keyring setup
#
# Cinder client keyring setup
#
# @example
#   include openstack::ceph::cinder_client
class openstack::ceph::cinder_client {
  include openstack::ceph::ceph_client
  # from https://docs.ceph.com/en/latest/rbd/rbd-openstack/#setup-ceph-client-authentication
  #
  # Add the keyrings for client.cinder, client.glance, and client.cinder-backup
  # to the appropriate nodes and change their ownership:
  #
  # ceph auth get-or-create client.cinder | ssh {your-volume-server} sudo tee /etc/ceph/ceph.client.cinder.keyring
  # ssh {your-cinder-volume-server} sudo chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring
  #
  # Nodes running nova-compute need the keyring file:
  #
  # ceph auth get-or-create client.cinder | ssh {your-nova-compute-server} sudo tee /etc/ceph/ceph.client.cinder.keyring
  #
  File <<| title == '/etc/ceph/ceph.client.cinder.keyring' |>>
  File <<| title == '/etc/ceph/ceph.client.cinder.key' |>>
}
