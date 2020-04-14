$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_subnet) do
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

  require 'English'

  ensurable

  newparam(:name, namevar: true) do
    desc 'New network name'
  end

  newparam(:id) do
    desc 'Subnet ID (read only)'
  end

  newparam(:ip_version) do
    desc 'IP version (default is 4). Note that when subnet pool is specified,
    IP version is determined from the subnet pool and this option is ignored.'

    newvalues('4', '6')
  end

  newparam(:dhcp) do
    desc 'Enable DHCP (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newparam(:network, parent: PuppetX::OpenStack::NetworkProperty) do
    desc 'Network this subnet belongs to (name or ID)'
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty) do
    desc "Owner's project (name or ID)"
  end

  newproperty(:subnet_range) do
    desc 'Subnet range in CIDR notation'

    validate do |value|
      raise ArgumentError, _('Subnet range must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('Subnet range must be a valid IP address') unless resource.validate_ip(value)
    end
  end

  newparam(:allocation_pool) do
    desc 'Enable Allocation pool IP addresses for this subnet (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:allocation_pool_start) do
    desc 'Allocation pool IP addresses for this subnet (start)'

    validate do |value|
      raise ArgumentError, _('Allocation pool IP address must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('Allocation pool IP address must be a valid IP address') unless resource.validate_ip(value)
    end
  end

  newproperty(:allocation_pool_end) do
    desc 'Allocation pool IP addresses for this subnet (end)'

    validate do |value|
      raise ArgumentError, _('Allocation pool IP address must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('Allocation pool IP address must be a valid IP address') unless resource.validate_ip(value)
    end
  end

  newproperty(:dns_nameserver, array_matching: :all) do
    desc 'DNS server for this subnet (repeat option to set multiple DNS servers)'

    def insync?(is)
      return @should == [:absent] if is.nil? || is == []
      is.flatten.sort == should.flatten.sort
    end

    validate do |value|
      next if value.to_s == 'absent'
      raise ArgumentError, _('DNS IP address must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('DNS IP address must be a valid IP address') unless resource.validate_ip(value)
    end
  end

  newproperty(:gateway) do
    desc 'Allocation pool IP addresses for this subnet (start)'

    validate do |value|
      raise ArgumentError, _('Gateway IP address must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('Gateway IP address must be a valid IP address') unless resource.validate_ip(value)
    end
  end

  newproperty(:description) do
    desc 'Set subnet description'
  end

  autorequire(:openstack_network) do
    self[:network]
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
  end

  validate do
    return true if self[:validation] == :false

    net_name = self[:network]
    raise Puppet::Error, 'Network must be provided' unless net_name

    net = network_instance(net_name) || network_resource(net_name)
    raise Puppet::Error, 'Network must be defined in catalog or existing in environment' unless net
  end

  def validate_ip(ip, name = 'IP address')
    IPAddr.new(ip) if ip
  rescue ArgumentError
    raise Puppet::Error, _("'%{ip}' is an invalid %{name}") % { ip: ip, name: name }, $ERROR_INFO
  end
end
