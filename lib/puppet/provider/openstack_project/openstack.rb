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
    get_list_array(provider_subcommand)
  end

  def self.provider_create(*args)
    cmdout = openstack_caller(provider_subcommand, 'create', '-f', 'json', *args)
    return cmdout unless cmdout

    begin
      JSON.parse(cmdout)
    rescue JSON::JSONError
      cmdout
    end
  end

  def self.provider_delete(*args)
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.provider_set(*args)
    openstack_caller(provider_subcommand, 'set', *args)
  end

  def self.domain_instances
    provider_instances(:openstack_domain).map { |d| [d.id, d.name] }.to_h
  end

  def self.add_instance(entity = {})
    @instances = [] unless @instances

    # name
    project_name = entity['name']

    # domain
    domain_id = entity['domain_id']
    domain_name = if domain_id == 'default'
                    'default'
                  else
                    domain_instances[domain_id]
                  end

    entity_name = (domain_id == 'default') ? project_name : "#{domain_name}/#{project_name}"

    # [<domain>/]<project>
    @instances << new(name: entity_name,
                      ensure: :present,
                      id: entity['id'],
                      domain: domain_name,
                      project_name: project_name,
                      description: entity['description'],
                      enabled: entity['enabled'].to_s.to_sym,
                      provider: name)
  end

  def self.delete_instance(id)
    @instances.reject! { |i| i.id == id }
  end

  def self.instances
    return @instances if @instances

    openstack_command

    provider_list.each { |entity| add_instance(entity) }

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
    project_name = @resource.value(:project_name)
    domain       = @resource.value(:domain)
    desc         = @resource.value(:description)
    enabled      = @resource.value(:enabled)
    name         = (domain == 'default') ? project_name : "#{domain}/#{project_name}"

    @property_hash[:name] = name
    @property_hash[:domain] = domain
    @property_hash[:project_name] = project_name
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
    args << project_name

    auth_args

    cmdout = self.class.provider_create(*args)

    return if cmdout == false
    self.class.add_instance(cmdout) if cmdout.is_a?(Hash)

    @property_hash[:ensure] = :present
  end

  def destroy
    project = @property_hash[:id]

    return if self.class.provider_delete(project) == false
    self.class.delete_instance(project)

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
    project_name = @resource.value(:project_name)
    domain       = @resource.value(:domain)
    desc         = @resource.value(:description)

    args << if @property_flush[:enabled] == :true
              '--enable'
            else
              '--disable'
            end
    args += ['--description', desc] if @property_flush[:description]

    @property_flush.clear

    return if args.empty?

    args += ['--domain', domain]
    args << project_name

    auth_args

    self.class.provider_set(*args)
  end
end
