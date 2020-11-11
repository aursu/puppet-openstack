require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_network).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'Manage networks for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'network'
  end

  def self.provider_list
    if Facter.value(:openstack)
      Facter.value(:openstack)['networks']
    else
      get_list(provider_subcommand)
    end
  end

  def self.provider_create(*args)
    openstack_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.provider_set(*args)
    openstack_caller(provider_subcommand, 'set', *args)
  end

  def self.add_instance(entity_name, entity = {})
    @instances = [] unless @instances

    project_id            = entity['project']      || entity['project_id']
    external              = entity['router_type']  || entity['router:external']
    admin_state_up        = entity['state']        || entity['admin_state_up']
    provider_network_type = entity['network_type'] || entity['provider:network_type']

    project_domain = project_instances[project_id]['domain']

    @instances << new(name: entity_name,
                      ensure: :present,
                      id: entity['id'],
                      subnets: entity['subnets'],
                      external: external.to_s.to_sym,
                      shared: entity['shared'].to_s.to_sym,
                      description: entity['description'],
                      enabled: admin_state_up.to_s.to_sym,
                      provider_network_type: provider_network_type,
                      project: project_id,
                      project_domain: project_domain,
                      provider: name)
  end

  def self.instances
    return @instances if @instances

    openstack_command

    provider_list.each { |entity| add_instance(*entity) }

    @instances || []
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
    name                      = @resource[:name]
    project                   = @resource.value(:project) unless @resource.value(:project).to_s.empty?
    project_domain            = @resource.value(:project_domain) unless @resource.value(:project_domain).to_s.empty?
    shared                    = @resource.value(:shared)
    external                  = @resource.value(:external)
    desc                      = @resource.value(:description)
    enabled                   = @resource.value(:enabled)
    provider_physical_network = @resource.value(:provider_physical_network)
    provider_network_type     = @resource.value(:provider_network_type)

    @property_hash[:shared] = shared
    @property_hash[:external] = external
    @property_hash[:description] = desc if desc
    @property_hash[:enabled] = enabled
    @property_hash[:provider_physical_network] = provider_physical_network if provider_physical_network
    @property_hash[:provider_network_type] = provider_network_type if provider_network_type

    args = []

    if project
      @property_hash[:project] = project
      args += ['--project', project]

      if project_domain
        @property_hash[:project_domain] = project_domain
        args += ['--project-domain', project_domain]
      end
    end

    args << '--share' if shared == :true
    args << '--no-share' if shared == :false

    args << '--external' if external == :true
    args << '--internal' if external == :false

    args += ['--description', desc] if desc

    args << '--enable' if enabled == :true
    args << '--disable' if enabled == :false

    args += ['--provider-physical-network', provider_physical_network] if provider_physical_network
    args += ['--provider-network-type', provider_network_type] if provider_network_type

    args << name

    auth_args

    self.class.provider_create(*args)

    @property_hash[:ensure] = :present
  end

  def destroy
    name = @resource[:name]

    self.class.provider_delete(name)

    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  def project=(proj)
    @property_flush[:project] = proj
  end

  def shared=(stat)
    @property_flush[:shared] = stat
  end

  def external=(stat)
    @property_flush[:external] = stat
  end

  def description=(desc)
    @property_flush[:description] = desc
  end

  def enabled=(stat)
    @property_flush[:enabled] = stat
  end

  def provider_network_type=(net_type)
    @property_flush[:provider_network_type] = net_type
  end

  def flush
    return if @property_flush.empty?
    args = []

    name                  = @resource[:name]
    project               = @resource.value(:project)
    project_domain        = @resource.value(:project_domain)
    desc                  = @resource.value(:description)
    provider_network_type = @resource.value(:provider_network_type)

    if @property_flush[:project]
      args += ['--project', project]
      args += ['--project-domain', project_domain] unless project_domain.to_s.empty?
    end

    args << '--share' if @property_flush[:shared] == :true
    args << '--no-share' if @property_flush[:shared] == :false

    args << '--external' if @property_flush[:external] == :true
    args << '--internal' if @property_flush[:external] == :false

    args += ['--description', desc] if @property_flush[:description]

    args << '--enable' if @property_flush[:enabled] == :true
    args << '--disable' if @property_flush[:enabled] == :false

    args += ['--provider-network-type', provider_network_type] if @property_flush[:provider_network_type]

    @property_flush.clear

    return if args.empty?
    args << name

    auth_args

    self.class.provider_set(*args)
  end
end
