require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_role).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'Manage roles for OpenStack.'

  commands openstack: 'openstack'

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'role'
  end

  def self.provider_list
    get_list(provider_subcommand, 'name', false)
  end

  def self.provider_create(*args)
    @prefetch_done = false
    openstack_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    @prefetch_done = false
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.instances
    return @instances if @instances && @prefetch_done
    @instances = []

    openstack_command

    provider_list.map do |entity_name, entity|
      @instances << new(name: entity_name,
                        ensure: :present,
                        id: entity['id'],
                        domain: nil,
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
    name    = @resource[:name]
    domain  = @resource.value(:domain)

    @property_hash[:domain] = domain if domain

    args = []
    args += ['--domain', domain] if domain
    args << name

    return if self.class.provider_create(*args) == false

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
end
