require 'English'

Facter.add(:ceph_conf) do
  confine { File.exist? '/etc/ceph/ceph.client.admin.keyring' }
  confine { File.exist? '/etc/ceph/ceph.conf' }
  setcode do
    File.read('/etc/ceph/ceph.conf')
  end
end

# It is for default cluster name `ceph`
# based on https://docs.ceph.com/en/latest/rbd/rbd-openstack/
Facter.add(:ceph_client_glance) do
  confine { File.exist? '/etc/ceph/ceph.client.admin.keyring' }
  setcode do
    client_keyring = Puppet::Util::Execution.execute('/usr/bin/ceph auth get client.glance', combine: false) if File.executable?('/usr/bin/ceph')

    if client_keyring && $CHILD_STATUS.success?
       client_keyring
    else
      nil
    end
  end
end

Facter.add(:ceph_client_cinder) do
  confine { File.exist? '/etc/ceph/ceph.client.admin.keyring' }
  setcode do
    client_keyring = Puppet::Util::Execution.execute('/usr/bin/ceph -f json auth get client.cinder', combine: false) if File.executable?('/usr/bin/ceph')

    return nil unless client_keyring && $CHILD_STATUS.success?

    JSON.parse(client_keyring).first
  end
end

Facter.add(:ceph_client_cinder_backup) do
  confine { File.exist? '/etc/ceph/ceph.client.admin.keyring' }
  setcode do
    client_keyring = Puppet::Util::Execution.execute('/usr/bin/ceph auth get client.cinder-backup', combine: false) if File.executable?('/usr/bin/ceph')

    return nil unless client_keyring && $CHILD_STATUS.success?

    client_keyring
  end
end

Facter.add(:ceph_ssh_pub_key) do
  confine { File.exist? '/etc/ceph/ceph.client.admin.keyring' }
  setcode do
    pub_key = `/usr/bin/ceph cephadm get-pub-key` if File.executable?('/usr/bin/ceph')

    return nil unless pub_key && $CHILD_STATUS.success?

    pub_key
  end
end