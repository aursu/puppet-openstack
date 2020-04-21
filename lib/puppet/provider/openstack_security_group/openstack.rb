require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_security_group).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'A security group acts as a virtual firewall for servers and other
    resources on a network. It is a container for security group rules which
    specify the network access rules.'

  # Generates method for all properties of the property_hash
  mk_resource_methods

  commands openstack: 'openstack'

  def self.provider_subcommand
    'security group'
  end

  def self.provider_list
    get_list_array(provider_subcommand, false)
  end

  def self.provider_create(*args)
    openstack_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.instances
    return @instances if @instances
    @instances = []

    openstack_command

    project_instances = provider_instances(:openstack_project).map { |p| [p.id, p.name] }.to_h

    provider_list.each do |entity|
      project_id = entity['project']
      group_name = entity['name']

      project_name = project_id.to_s.empty? ? '' : project_instances[project_id]

      group_project_name = project_name.empty? ? group_name : "#{project_name}/#{group_name}"

      @instances << new(name: group_project_name,
          ensure: :present,
          id: entity['id'],
          name: group_name,
          project: project_name,
          description: entity['description'],
          provider: name)
    end

    @instances
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
    name    = @resource[:name]
    desc    = @resource.value(:description)
    project = @resource.value(:project)

    @property_hash[:description] = desc if desc
    @property_hash[:project] = project if project

    # openstack security group create
    # [--description <description>]
    # [--project <project> [--project-domain <project-domain>]]
    # [--tag <tag> | --no-tag]
    # <name>

    args = []
    args += ['--project', project] if project && !project.empty?
    args += ['--description', desc] if desc
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
