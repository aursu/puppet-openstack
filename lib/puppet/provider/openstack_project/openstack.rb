require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_project).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'manage projects for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'project'
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
    return @instances if @instances
    @instances = []

    openstack_command

    provider_list.map do |entity_name, entity|
      @instances << new(name: entity_name,
          ensure: :present,
          id: entity['id'],
          domain: entity['domain_id'],
          description: entity['description'],
          enabled: entity['enabled'].to_s.to_sym,
          provider: name)
    end

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
    name    = @resource[:name]
    domain  = @resource.value(:domain)
    desc    = @resource.value(:description)
    enabled = @resource.value(:enabled)

    @property_hash[:domain] = domain
    @property_hash[:description] = desc
    @property_hash[:enabled] = enabled

    args = []
    args += ['--domain', domain] if domain
    args += ['--description', desc] if desc
    args << if [true, :true].include?(enabled)
              '--enable'
            else
              '--disable'
            end
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

  def description=(desc)
    @property_flush[:description] = desc
  end

  def enabled=(stat)
    @property_flush[:enabled] = stat
  end

  def flush
    return if @property_flush.empty?
    args = []
    name    = @resource[:name]
    desc    = @resource.value(:description)

    args << if @property_flush[:enabled] == :true
              '--enable'
            else
              '--disable'
            end
    args += ['--description', desc] if @property_flush[:description]

    @property_flush.clear

    return if args.empty?

    args << name

    auth_args

    self.class.provider_set(*args)
  end
end
