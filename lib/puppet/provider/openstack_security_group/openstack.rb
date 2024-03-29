require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_security_group).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'A security group acts as a virtual firewall for servers and other
    resources on a network. It is a container for security group rules which
    specify the network access rules.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'security group'
  end

  def self.provider_list
    get_list_array(provider_subcommand, false)
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

  def self.add_instance(entity = {})
    @instances = [] unless @instances

    entity_id = entity['id']
    project_id = entity['project_id'] || entity['project']
    # default project
    project_name = if project_id == 'default'
                     'default'
                   elsif project_id.to_s.empty?
                     ''
                   else
                     project_instances[project_id]['name']
                   end
    project_domain = if project_instances[project_id]
                       project_instances[project_id]['domain']
                     else
                       'default'
                     end
    group_name = entity['name']

    entity_name = group_name.to_s
    entity_name = "group-#{entity_id}" if entity_name.empty?

    group_project_name = if group_name.to_s.empty?
                           entity_name
                         else
                           project_name.to_s.empty? ? group_name : "#{project_name}/#{group_name}"
                         end

    @instances << new(name: group_project_name,
                      ensure: :present,
                      id: entity['id'],
                      group_name: group_name,
                      project: project_name,
                      project_domain: project_domain,
                      description: entity['description'],
                      provider: name)
  end

  def self.delete_instance(id)
    @instances.reject! { |i| i.id == id }
  end

  def self.instances
    if @instances
      return @instances if @prefetch_done
      # reset it
      @instances = []
    end

    openstack_command

    provider_list.each { |entity| add_instance(entity) }
    @prefetch_done = true

    @instances || []
  end

  def self.prefetch(resources)
    entities = instances
    resources.keys.each do |entity_name|
      # rubocop:disable Lint/AssignmentInCondition
      if provider = entities.find { |entity| entity.name == entity_name }
        resources[entity_name].provider = provider
      end
      # rubocop:enable Lint/AssignmentInCondition
    end
  end

  def create
    group_name     = @resource.value(:group_name)
    desc           = @resource.value(:description)
    project_domain = @resource.value(:project_domain)

    project    = @resource.value(:project)
    project    = nil if project.to_s.empty?

    name       = project ? group_name : "#{project}/#{group_name}"

    @property_hash[:name] = name
    @property_hash[:group_name] = group_name
    @property_hash[:description] = desc if desc
    @property_hash[:project] = project if project

    # openstack security group create
    # [--description <description>]
    # [--project <project> [--project-domain <project-domain>]]
    # [--tag <tag> | --no-tag]
    # <name>

    args = []
    if project
      @property_hash[:project] = project
      args += ['--project', project]

      if project_domain
        @property_hash[:project_domain] = project_domain
        args += ['--project-domain', project_domain]
      end
    end
    args += ['--description', desc] if desc
    args << group_name

    auth_args

    cmdout = self.class.provider_create(*args)

    return if cmdout == false
    self.class.add_instance(cmdout) if cmdout.is_a?(Hash)

    @property_hash[:ensure] = :present
  end

  def destroy
    group = @property_hash[:id]

    return if self.class.provider_delete(group) == false
    self.class.delete_instance(group)

    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  # openstack security group set
  # [--name <new-name>]
  # [--description <description>]
  # [--tag <tag>] [--no-tag]
  # <group>
  def description=(desc)
    group = @property_hash[:id]

    args = ['--description', desc]
    args << group

    auth_args

    self.class.provider_set(*args)
  end
end
