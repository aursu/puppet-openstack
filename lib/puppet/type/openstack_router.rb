$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_router) do
  extend CustomComm
  include CustomType

  @doc = <<-PUPPET
    @summary
      A router is a logical component that forwards data packets between
      networks. It also provides Layer 3 and NAT forwarding to provide external
      network access for servers on project networks.

      https://docs.openstack.org/python-openstackclient/train/cli/command-objects/router.html
    PUPPET

  ensurable

  newparam(:name) do
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

  newproperty(:external_gateway_network, parent: PuppetX::OpenStack::NetworkProperty) do
    desc "Network used as router's external gateway network (name or ID)"

    munge do |value|
      return :absent if value.to_s == 'absent'

      network = resource.network_instance(value)
      value = network[:id] if network

      value
    end
  end

  newproperty(:external_gateway_subnet, parent: PuppetX::OpenStack::SubnetProperty) do
    desc "Subnet used as router's external gateway subnet (name or ID)"

    munge do |value|
      return :absent if value.to_s == 'absent'

      subnet = resource.subnet_instance(value)
      value = subnet[:id] if subnet

      value
    end
  end

  newproperty(:external_gateway_ip) do
    desc 'IP on external gateway'

    validate do |value|
      raise ArgumentError, _('Gateway IP address must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('Gateway IP address must be a valid IP address') unless resource.validate_ip(value)
    end
  end

  newproperty(:subnets, parent: PuppetX::OpenStack::SubnetProperty, array_matching: :all) do
    desc 'Router subnets'

    # no removal
    def insync?(is)
      # is == :absent in case of non-existing subnets for router
      return @should == [:absent] if is.nil? || is == [] || is.to_s == 'absent'

      # all subnets in @should array should be defined to be in sync
      (@should.compact - is).empty?
    end

    munge do |value|
      return :absent if value.to_s == 'absent'

      subnet = resource.subnet_instance(value)
      value = subnet[:id] if subnet

      value
    end
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
  end

  autorequire(:openstack_subnet) do
    prop_to_array(self[:subnets]).map { |s| subnet_instance(s) || subnet_resource(s) }.compact
                                 .map { |s| s[:name] }
  end

  validate do
    if @parameters[:external_gateway_subnet] || @parameters[:external_gateway_ip]
      raise Puppet::Error, _('error: argument :external_gateway_ip not allowed without argument :external_gateway_subnet') \
        unless @parameters[:external_gateway_subnet] && @parameters[:external_gateway_ip]
    end
  end

  def validate_ip(ip, name = 'IP address')
    IPAddr.new(ip) if ip
  rescue ArgumentError
    raise Puppet::Error, _("'%{ip}' is an invalid %{name}") % { ip: ip, name: name }, $ERROR_INFO
  end
end
