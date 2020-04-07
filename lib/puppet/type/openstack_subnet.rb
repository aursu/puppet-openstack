Puppet::Type.newtype(:openstack_subnet) do
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

  newparam(:network) do
    desc 'Network this subnet belongs to (name or ID)'

    validate do |value|
      raise ArgumentError, _('Network must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('Network must be non-empty String') if value.empty?
    end
  end

  newproperty(:project) do
    desc "Owner's project (name or ID)"

    def insync?(_is)
      p = resource.project_instance(@should)
      return false if p.nil?

      true
    end
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

    validate do |value|
      unless value == :absent
        value = [value] unless value.is_a?(Array)
        value.each do |ip|
          raise ArgumentError, _('DNS IP address must be a String not %{klass}') % { klass: ip.class } unless ip.is_a?(String)
          raise ArgumentError, _('DNS IP address must be a valid IP address') unless resource.validate_ip(ip)
        end
      end
    end

    munge do |value|
      case value
      when String
        [value]
      when Array
        value
      else
        :absent
      end
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
    [self[:network]]
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
  end

  validate do
    net_name = self[:network]
    raise 'Network must be provided' unless net_name

    net_inst = network_instance(net_name)
    net_res = network_resource(net_name)

    raise 'Network must be defined in catalog or existing in environment' unless net_inst || net_res
  end

  def project_instance(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id

    instances = Puppet::Type.type(:openstack_project).instances
                            .select { |resource| resource[:name] == lookup_id || resource[:id] == lookup_id }
    return nil if instances.empty?
    # no support for multiple OpenStack domains
    instances.first
  end

  def network_instance(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id

    instances = Puppet::Type.type(:openstack_network).instances
                            .select { |resource| resource[:name] == lookup_id || resource[:id] == lookup_id }
    return nil if instances.empty?
    # no support for multiple OpenStack domains
    instances.first
  end

  def network_resource(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id
    catalog.resources.find { |r| r.is_a?(Puppet::Type.type(:openstack_network)) && [r[:name], r[:id]].include?(lookup_id) }
  end

  def validate_ip(ip, name = 'IP address')
    IPAddr.new(ip) if ip
  rescue ArgumentError
    raise Puppet::Error, _("'%{ip}' is an invalid %{name}") % { ip: ip, name: name }, $ERROR_INFO
  end
end
