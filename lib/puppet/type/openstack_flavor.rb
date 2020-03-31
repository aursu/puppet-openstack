Puppet::Type.newtype(:openstack_flavor) do
  @doc = <<-PUPPET
    @summary
      In OpenStack, a flavor defines the compute, memory, and storage capacity
      of a virtual server, also known as an instance. As an administrative user,
      you can create, edit, and delete flavors.
    PUPPET

  ensurable

  newparam(:name, namevar: true) do
    desc "A descriptive name. XX.SIZE_NAME is typically not required, though
    some third party tools may rely on it."
  end

  newproperty(:ram) do
    desc 'Memory size in MB (default 256M)'
    newvalue(%r{\d+})
    defaultto 256
  end

  newproperty(:disk) do
    desc 'Disk size in GB (default 0G)'
    newvalue(%r{\d+})
    defaultto 0
  end

  newproperty(:ephemeral) do
    desc 'Ephemeral disk size in GB (default 0G)'
    newvalue(%r{\d+})
    defaultto 0
  end

  newproperty(:swap) do
    desc 'Additional swap space size in MB (default 0M)'
    newvalue(%r{\d+})
    defaultto 0
  end

  newproperty(:vcpus) do
    desc 'Number of vcpus (default 1)'
    newvalue(%r{\d+})
    defaultto 1
  end
end
