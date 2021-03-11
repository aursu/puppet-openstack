$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customprop'

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

  newparam(:name) do
    desc 'Port name'
  end

  newparam(:port_name) do
    desc 'Real port name (could be unset)'
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty) do
    desc "Owner's project (name or ID)"

    validate do |value|
      next if value.to_s == ''

      super(value)
    end
  end

  # --project-domain
  newparam(:project_domain, parent: PuppetX::OpenStack::DomainParameter) do
    desc 'Domain the project belongs to (name or ID).'
  end

  newproperty(:network, parent: PuppetX::OpenStack::NetworkProperty) do
    desc 'Network this port belongs to (name or ID)'
  end

  newparam(:id) do
    desc 'Port ID (read only)'
  end

  newproperty(:device_id) do
    desc 'Port device ID'
  end

  newproperty(:device_owner) do
    desc 'Device owner of this port. this is the entity that uses the port'
  end

  newparam(:mac_address) do
    desc 'MAC address of this port'
  end

  newparam(:fixed_ips, array_matching: :all) do
    desc 'Desired IP and/or subnet for this port (name or ID)'

    validate do |value|
      # allow to use :absent explicitly
      next if value.to_s == 'absent'

      if value.is_a?(Hash) && value['subnet_id']
        subnet_id = value['subnet_id']

        return true unless resource.catalog

        subnet = resource.subnet_instance(subnet_id) || resource.subnet_resource(subnet_id)
        raise ArgumentError, _("Subnet #{subnet_id} must be defined in catalog or exist in OpenStack environment") unless subnet

        next if value['ip_address']
      end

      raise ArgumentError, _('Fixed IPs must be provided as a Hash with keys subnet_id and ip_address')
    end

    def insync?(is)
      # we do not delete anythinng from OpenStack (sync if absent)
      return true if @should == [:absent]

      is = is.map { |v| [v['subnet_id'], v['ip_address']] }.to_h
      should = @should.map { |v| [v['subnet_id'], v['ip_address']] }.to_h

      # all properties in @should array must be defined to be in sync
      should.all? { |k, _v| should[k] == is[k] }
    end

    munge do |value|
      return :absent if value.to_s == 'absent'

      sub = resource.subnet_instance(value['subnet_id'])
      value['subnet_id'] = sub[:id] if sub

      value
    end
  end

  newproperty(:description) do
    desc 'Description of this port'
  end

  newproperty(:host_id) do
    desc 'Allocate port on host <host-id> (id only)'
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

  newproperty(:security_group, parent: PuppetX::OpenStack::SecurityGroupProperty, array_matching: :all) do
    desc 'Security group to associate with this port.'

    def insync?(is)
      return @should == [:absent] if is.nil? || is == [] || is.to_s == 'absent'

      # all security groups in @should array should be defined to be in sync
      (@should.compact - is).empty?
    end

    munge do |value|
      return :absent if value.to_s == 'absent'

      sub = resource.security_group_instance(value)
      value = sub[:id] if sub

      value
    end
  end

  validate do
    return true if self[:validation] == :false

    net_name = self[:network]
    raise Puppet::Error, 'Network must be provided' unless net_name

    # return true unless catalog

    # net = network_instance(net_name) || network_resource(net_name)
    # raise Puppet::Error, "Network #{net_name} must be defined in catalog or exist in OpenStack environment" unless net
  end
end
