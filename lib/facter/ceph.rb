require 'English'
require 'puppet/util/execution'

Facter.add(:ceph_conf) do
  confine { File.exist? '/etc/ceph/ceph.client.admin.keyring' }
  confine { File.exist? '/etc/ceph/ceph.conf' }
  setcode do
    obj = {}

    content = File.read('/etc/ceph/ceph.conf').gsub(%r{\r*\n+}, "\n")

    section = nil
    content.each_line do |line|
      # no spaces
      line.strip!

      #  no comments
      next if line.match?(%r{^#})

      # section
      if (line =~ %r{^\[(.*)\]\s*$})
        section = $1
        obj[section] = {}

        next
      end

      if (line =~ %r{^([^=]+?)\s*=\s*(.*?)\s*$})
        next if !section

        param, value = line.split(%r{\s*=\s*}, 2)

        param.strip!
        value.strip!

        obj[section][param] = value
      end
    end

    obj
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

Facter.add(:ceph_client_cinder_key) do
  confine { File.exist? '/etc/ceph/ceph.client.admin.keyring' }
  setcode do
    Facter.value(:ceph_client_cinder)['key']
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

Facter.add(:ceph_client_cinder_key_exported) do
  confine { File.exist? '/root/ceph/ceph.client.cinder.key' }
  setcode do
    File.read('/root/ceph/ceph.client.cinder.key')
  end
end

Facter.add(:ceph_ssh_pub_key_exported) do
  confine { File.exist? '/root/ceph/ceph.pub' }
  setcode do
    pub_key = File.read('/root/ceph/ceph.pub').strip.split(%r{\s+})
    {
      'type' => pub_key[-3],
      'key'  => pub_key[-2],
      'name' => pub_key[-1],
    }
  end
end

Facter.add(:ceph_conf_exported) do
  confine { File.exist? '/root/ceph/ceph.conf' }
  setcode do
    obj = {}

    content = File.read('/root/ceph/ceph.conf').gsub(%r{\r*\n+}, "\n")

    section = nil
    content.each_line do |line|
      # no spaces
      line.strip!

      #  no comments
      next if line.match?(%r{^#})

      # section
      if (line =~ %r{^\[(.*)\]\s*$})
        section = $1
        obj[section] = {}

        next
      end

      if (line =~ %r{^([^=]+?)\s*=\s*(.*?)\s*$})
        next if !section

        param, value = line.split(%r{\s*=\s*}, 2)

        param.strip!
        value.strip!

        obj[section][param] = value
      end
    end

    obj
  end
end