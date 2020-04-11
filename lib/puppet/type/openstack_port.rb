$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'

Puppet::Type.newtype(:openstack_port) do
  extend CustomComm
  include CustomType

  @doc = <<-PUPPET
    @summary
      A port is a connection point for attaching a single device, such as the
      NIC of a server, to a network. The port also describes the associated
      network configuration, such as the MAC and IP addresses to be used on
      that port.
    PUPPET

  ensurable

  newparam(:name, namevar: true) do
    desc 'Port name'
  end

  newparam(:real_name) do
    desc 'Real port name (could be unset)'
  end

  newparam(:network) do
    desc 'Network this port belongs to (name or ID)'

    validate do |value|
      raise ArgumentError, _('Network must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('Network must be non-empty String') if value.empty?
    end
  end

  newparam(:id) do
    desc 'Port ID (read only)'
  end

  newproperty(:device_id) do
    desc 'Port device ID'
  end

  newparam(:mac_address) do
    desc 'MAC address of this port'
  end

  newparam(:fixed_ips) do
    desc 'Desired IP and/or subnet for this port (name or ID)'
  end

  newproperty(:description) do
    desc 'Description of this port'
  end

  newproperty(:enabled) do
    desc 'Enable port (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:port_security) do
    desc 'Enable port security for this port'

    newvalues(:true, :false)
    defaultto :false
  end

  validate do
    net_name = self[:network]
    raise 'Network must be provided' unless net_name

    net_inst = network_instance(net_name)
    net_res = network_resource(net_name)

    raise 'Network must be defined in catalog or exist in OpenStack environment' unless net_inst || net_res
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
end
