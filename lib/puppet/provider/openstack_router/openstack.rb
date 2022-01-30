require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_router).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'Manage routers for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'router'
  end

  def self.provider_list
    get_list(provider_subcommand)
  end

  def self.provider_create(*args)
    @prefetch_done = false
    openstack_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    @prefetch_done = false
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.provider_set(*args)
    openstack_caller(provider_subcommand, 'set', *args)
  end

  # "External gateway info": {
  #   "network_id": "107ce2d3-68c7-4c4a-bc04-e29c38ab5282",
  #   "enable_snat": true,
  #   "external_fixed_ips": [
  #     {
  #       "subnet_id": "ac6d8652-c52a-4f31-b610-26bddcecbec2",
  #       "ip_address": "10.100.16.30"
  #     }
  #   ]
  # },

  def self.instances
    return @instances if @instances && @prefetch_done
    @instances = []

    openstack_command

    port_instances = provider_instances(:openstack_port).select { |port| port.fixed_ips.is_a?(Array) }

    provider_list.map do |entity_name, entity|
      router_id = entity['id']

      external_gateway_info = entity['external_gateway_info']
      external_gateway_info = external_gateway_info['network_id'] if external_gateway_info.is_a?(Hash)

      router_subnets = port_instances.select { |port| port.device_id == router_id }
                                     .map { |port| port.fixed_ips }.flatten
                                     .map { |ip| ip['subnet_id'] }.compact
      router_subnets = nil if router_subnets.empty?

      @instances << new(name: entity_name,
                        ensure: :present,
                        id: entity['id'],
                        description: entity['description'],
                        enabled: entity['state'].to_s.to_sym,
                        project: entity['project'],
                        distributed: entity['distributed'].to_s.to_sym,
                        ha: entity['ha'].to_s.to_sym,
                        external_gateway_info: external_gateway_info,
                        subnets: router_subnets,
                        provider: name)
    end

    @prefetch_done = true
    @instances
  end

  def self.prefetch(resources)
    entities = instances
    # rubocop:disable Lint/AssignmentInCondition
    resources.keys.each do |entity_name|
      if provider = entities.find { |entity| entity.name == entity_name }
        resources[entity_name].provider = provider
      end
    end
    # rubocop:enable Lint/AssignmentInCondition
  end

  def create
    name        = @resource[:name]
    enabled     = @resource.value(:enabled)
    distributed = @resource.value(:distributed)
    ha          = @resource.value(:ha)
    desc        = @resource.value(:description)
    project     = @resource.value(:project)
    subnets     = @resource.value(:subnets)
    external_gateway_info = @resource.value(:external_gateway_info)

    @property_hash[:enabled] = enabled
    @property_hash[:distributed] = distributed
    @property_hash[:ha] = ha
    @property_hash[:description] = desc if desc
    @property_hash[:project] = project if project && !project.empty?

    args = []
    args << '--enable' if enabled == :true
    args << '--disable' if enabled == :false
    args << '--distributed' if distributed == :true
    args << '--centralized' if distributed == :false
    args << '--ha' if ha == :true
    args << '--no-ha' if ha == :false
    args += ['--description', desc] if desc
    args += ['--project', project] if project

    args << name

    auth_args

    return if self.class.provider_create(*args) == false
    @property_hash[:ensure] = :present

    return if self.class.provider_set('--external-gateway', external_gateway_info, name) == false
    # TODO: openstack router set --external-gateway 107ce2d3-68c7-4c4a-bc04-e29c38ab5282 \
    #       --fixed-ip subnet=ea91d300-c187-4001-900e-0b715edc4b7d,ip-address=10.100.16.58 59c172eb-91b1-49a4-b7a3-7bb3b48a219d
    @property_hash[:external_gateway_info] = external_gateway_info

    subnets.each do |sub|
      return if self.class.openstack_caller('router', 'add subnet', name, sub) == false # rubocop:disable Lint/NonLocalExitFromIterator:
    end
    @property_hash[:subnets] = subnets
  end

  def destroy
    name = @resource[:name]

    self.class.provider_delete(name)

    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  def description=(desc)
    @property_flush[:description] = desc
  end

  def enabled=(stat)
    @property_flush[:enabled] = stat
  end

  def distributed=(stat)
    @property_flush[:distributed] = stat
  end

  def ha=(stat)
    @property_flush[:ha] = stat
  end

  def external_gateway_info=(info)
    @property_flush[:external_gateway_info] = info
  end

  def subnets=(should)
    name = @resource[:name]

    is = [@property_hash[:subnets]].flatten.reject { |s| s.to_s == 'absent' }.compact

    (should - is).each do |s|
      next if self.class.openstack_caller('router add subnet', name, s) == false
      is << s
    end

    @property_hash[:subnets] = is unless is.empty?
  end

  def flush
    return if @property_flush.empty?
    args = []
    name        = @resource[:name]
    desc        = @resource.value(:description)
    external_gateway_info = @resource.value(:external_gateway_info)

    args += ['--description', desc] if @property_flush[:description]
    args << '--enable' if @property_flush[:enabled] == :true
    args << '--disable' if @property_flush[:enabled] == :false

    if @property_hash[:enabled].to_s == 'false'
      args << '--distributed' if @property_flush[:distributed] == :true
      args << '--centralized' if @property_flush[:distributed] == :false
      args << '--ha' if @property_flush[:ha] == :true
      args << '--no-ha' if @property_flush[:ha] == :false
    end

    args += ['--external-gateway', external_gateway_info] if @property_flush[:external_gateway_info]

    @property_flush.clear

    return if args.empty?
    args << name

    auth_args

    self.class.provider_set(*args)
  end
end
