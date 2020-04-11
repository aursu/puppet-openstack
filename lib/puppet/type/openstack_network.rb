$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_network) do
  extend CustomComm
  include CustomType

  @doc = <<-PUPPET
    @summary
      A network is an isolated Layer 2 networking segment. There are two types
      of networks, project and provider networks. Project networks are fully
      isolated and are not shared with other projects. Provider networks map to
      existing physical networks in the data center and provide external
      network access for servers and other resources. Only an OpenStack
      administrator can create provider networks. Networks can be connected via
      routers.

      https://docs.openstack.org/python-openstackclient/train/cli/command-objects/network.html
    PUPPET

  ensurable

  newparam(:name, namevar: true) do
    desc 'New network name'
  end

  newparam(:id) do
    desc 'Network ID (read only)'
  end

  newparam(:subnets) do
    desc 'Subnets (read only)'
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty) do
    desc 'Default project (name or ID)'
  end

  newproperty(:enabled) do
    desc 'Enable network (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:shared) do
    desc 'Share the network between projects'

    newvalues(:true, :false)
    defaultto :false
  end

  newproperty(:external) do
    desc 'Set this network as an external network (external-net extension required)'

    newvalues(:true, :false)
    defaultto :false
  end

  newproperty(:description) do
    desc 'Project description'
  end

  newproperty(:provider_physical_network) do
    desc 'Name of the physical network over which the virtual network is implemented'
  end

  newproperty(:provider_network_type) do
    desc <<-PUPPET
      The physical mechanism by which the virtual network is implemented.
      The supported options are: flat, geneve, gre, local, vlan, vxlan.
    PUPPET

    newvalues(:flat, :geneve, :gre, :local, :vlan, :vxlan)
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
  end
end
