$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_router) do
  extend CustomComm

  @doc = <<-PUPPET
    @summary
      A router is a logical component that forwards data packets between
      networks. It also provides Layer 3 and NAT forwarding to provide external
      network access for servers on project networks.

      https://docs.openstack.org/python-openstackclient/train/cli/command-objects/router.html
    PUPPET

  ensurable

  newparam(:name, namevar: true) do
    desc 'New router name'
  end

  newparam(:id) do
    desc 'Router ID (read only)'
  end

  newproperty(:distributed) do
    desc 'Set router to distributed mode'

    newvalues(:true, :false)
  end

  newproperty(:ha) do
    desc 'Set the router as highly available'

    newvalues(:true, :false)
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty) do
    desc "Owner's project (name or ID)"
  end

  newproperty(:enabled) do
    desc 'Enable router (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:description) do
    desc 'Router description'
  end

  newproperty(:external_gateway_info, parent: PuppetX::OpenStack::NetworkProperty) do
    desc "External Network used as router's gateway (name or ID)"
  end

  newproperty(:subnets, parent: PuppetX::OpenStack::SubnetProperty, array_matching: :all) do
    desc 'Router subnets'

    def insync?(is)
      return @should == [:absent] if is.nil? || is == []

      # all subnets in @should array should be defined to be in sync
      (@should.compact - is).empty?
    end

    munge do |value|
      return :absent if value.to_s == 'absent'

      sub = resource.subnet_instance(value)
      value = sub[:id] if sub

      value
    end
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
  end
end
