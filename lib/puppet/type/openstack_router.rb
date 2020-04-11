$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customcomm'

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

  newproperty(:project) do
    desc "Owner's project (name or ID)"

    def insync?(_is)
      p = resource.project_instance(@should)

      return false if p.nil?
      true
    end
  end

  newproperty(:enabled) do
    desc 'Enable router (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:description) do
    desc 'Router description'
  end

  newproperty(:external_gateway_info) do
    desc "External Network used as router's gateway (name or ID)"

    def insync?(_is)
      net_inst = resource.network_instance(@should)
      net_res = resource.network_resource(@should)

      return false if net_inst.nil? && net_res.nil?
      true
    end
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
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
end
