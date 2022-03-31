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
    apiclient.req_params = {}
    apiclient.api_get_list('routers')
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

  def self.provider_unset(*args)
    openstack_caller(provider_subcommand, 'unset', *args)
  end

  def self.instances
    return @instances if @instances && @prefetch_done
    @instances = []

    openstack_command

    port_instances = provider_instances(:openstack_port).select { |port| port.fixed_ips.is_a?(Array) }

    provider_list.map do |entity_name, entity|
      router_id = entity['id']

      external_gateway_network = nil
      external_gateway_subnet  = nil
      external_gateway_ip      = nil

      external_gateway_info = entity['external_gateway_info']
      if external_gateway_info.is_a?(Hash)
        external_gateway_network = external_gateway_info['network_id']
        external_fixed_ips       = external_gateway_info['external_fixed_ips']
        if external_fixed_ips.is_a?(Array) && external_fixed_ips[0]
          fixed_ip = external_fixed_ips[0]
          external_gateway_subnet = fixed_ip['subnet_id']
          external_gateway_ip     = fixed_ip['ip_address']
        end
      end

      router_subnets = port_instances.select { |port| port.device_id == router_id }
                                     .map    { |port| port.fixed_ips }.flatten
                                     .map    { |ip| ip['subnet_id'] }.compact

      router_subnets = nil if router_subnets.empty?

      enabled = entity['status'].casecmp?('ACTIVE')

      @instances << new(name: entity_name,
                        ensure: :present,
                        id: entity['id'],
                        description: entity['description'],
                        enabled: enabled.to_s.to_sym,
                        project: entity['project_id'],
                        distributed: entity['distributed'].to_s.to_sym,
                        ha: entity['ha'].to_s.to_sym,
                        external_gateway_network: external_gateway_network,
                        external_gateway_subnet: external_gateway_subnet,
                        external_gateway_ip: external_gateway_ip,
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

    external_gateway_network = @resource.value(:external_gateway_network)
    external_gateway_subnet  = @resource.value(:external_gateway_subnet)
    external_gateway_ip      = @resource.value(:external_gateway_ip)

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

    if external_gateway_network
      if external_gateway_subnet && external_gateway_ip
        return if self.class.provider_set('--external-gateway', external_gateway_network, "--fixed-ip subnet=#{external_gateway_subnet},ip-address=#{external_gateway_ip}", name) == false

        @property_hash[:external_gateway_subnet] = external_gateway_subnet
        @property_hash[:external_gateway_ip] = external_gateway_ip
      elsif self.class.provider_set('--external-gateway', external_gateway_network, name) == false
        return
      end
      @property_hash[:external_gateway_network] = external_gateway_network
    end

    subnets.each do |sub|
      return if self.class.openstack_caller('router', 'add subnet', name, sub) == false # rubocop:disable Lint/NonLocalExitFromIterator:
    end

    @property_hash[:subnets] = subnets
  end

  def destroy
    name = @resource[:name]

    return if self.class.provider_unset('--external-gateway', name) == false

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

  def external_gateway_network=(info)
    @property_flush[:external_gateway_network] = info
  end

  def external_gateway_subnet=(info)
    @property_flush[:external_gateway_subnet] = info
  end

  def external_gateway_ip=(info)
    @property_flush[:external_gateway_ip] = info
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
    external_gateway_network = @resource.value(:external_gateway_network)
    external_gateway_subnet  = @resource.value(:external_gateway_subnet)
    external_gateway_ip      = @resource.value(:external_gateway_ip)

    args += ['--description', desc] if @property_flush[:description]
    args << '--enable' if @property_flush[:enabled] == :true
    args << '--disable' if @property_flush[:enabled] == :false

    if @property_hash[:enabled].to_s == 'false'
      args << '--distributed' if @property_flush[:distributed] == :true
      args << '--centralized' if @property_flush[:distributed] == :false
      args << '--ha' if @property_flush[:ha] == :true
      args << '--no-ha' if @property_flush[:ha] == :false
    end

    if @property_flush[:external_gateway_network] || @property_flush[:external_gateway_subnet] || @property_flush[:external_gateway_ip]
      if external_gateway_network
        args += ['--external-gateway', external_gateway_network]
        if external_gateway_subnet && external_gateway_ip
          args += ['--fixed-ip', "subnet=#{external_gateway_subnet},ip-address=#{external_gateway_ip}"]
        end
      end
    end

    @property_flush.clear

    return if args.empty?
    args << name

    auth_args

    self.class.provider_set(*args)
  end
end
