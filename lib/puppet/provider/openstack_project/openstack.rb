require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_project).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'manage projects for OpenStack.'

  commands openstack: 'openstack'

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
    openstack_command

    provider_list.map do |entity_name, entity|
      new(name: entity_name,
          ensure: :present,
          id: entity['id'],
          domain: entity['domain_id'],
          description: entity['description'],
          enabled: entity['enabled'],
          provider: name)
    end
  end

  def self.prefetch(resources)
    entities = instances
    # rubocop:disable Lint/AssignmentInCondition
    resources.keys.each do |entity_name|
      if provider = entities.find { |entity| entity.name == entity_name }
        resources[name].provider = provider
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
    args << '--enable' if enabled
    args << '--disable' unless enabled
    args << name

    self.class.provider_create(*args)

    @property_hash[:ensure] = :present

    exists? ? (return true) : (return false)
  end

  def destroy
    name = @resource[:name]

    self.class.provider_delete(name)

    @property_hash.clear
    exists? ? (return false) : (return true)
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  def description=(desc)
    self.class.provider_set('--description', desc, @resource[:name])
    (description == desc) ? (return true) : (return false)
  end

  def domain=(dom)
    self.class.provider_set('--domain', dom, @resource[:name])
    (domain == dom) ? (return true) : (return false)
  end

  def enabled=(stat)
    if stat
      self.class.provider_set('--enable', @resource[:name])
    else
      self.class.provider_set('--disable', @resource[:name])
    end
    (enabled == stat) ? (return true) : (return false)
  end
end
