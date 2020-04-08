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
    openstack_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.provider_set(*args)
    openstack_caller(provider_subcommand, 'set', *args)
  end

  def self.instances
    openstack_command

    provider_list.map do |entity_name, entity|
      new(name: entity_name,
          ensure: :present,
          id: entity['id'],
          description: entity['description'],
          enabled: entity['state'].to_s.to_sym,
          project: entity['project'],
          distributed: entity['distributed'].to_s.to_sym,
          ha: entity['ha'].to_s.to_sym,
          provider: name)
    end
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

  def flush
    return if @property_flush.empty?
    args = []
    name        = @resource[:name]
    desc        = @resource.value(:description)

    args += ['--description', desc] if @property_flush[:description]
    args << '--enable' if @property_flush[:enabled] == :true
    args << '--disable' if @property_flush[:enabled] == :false

    if @property_hash[:enabled].to_s == 'false'
      args << '--distributed' if @property_flush[:distributed] == :true
      args << '--centralized' if @property_flush[:distributed] == :false
      args << '--ha' if @property_flush[:ha] == :true
      args << '--no-ha' if @property_flush[:ha] == :false
    end

    @property_flush.clear

    return if args.empty?
    args << name
    self.class.provider_set(*args)
  end
end
