require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_user).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'manage users for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'user'
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

    role_assignment = get_list('role assignment', key: ['user', 'project'], long: false)

    provider_list.map do |entity_name, entity|
      user_id = entity['id']
      user_role = role_assignment.select { |_i, assignment| assignment['user'] == user_id }
                                       .map { |_i, assignment| assignment['project'] }

      new(name: entity_name,
          ensure: :present,
          id: entity['id'],
          domain: entity['domain'],
          description: entity['description'],
          enabled: entity['enabled'],
          email: entity['email'],
          project: entity['project'],
          assignments: user_role,
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
    name    = @resource[:name]
    domain  = @resource.value(:domain)
    desc    = @resource.value(:description)
    enabled = @resource.value(:enabled)
    email   = @resource.value(:email)
    project = @resource.value(:project)
    pwd     = @resource.value(:password)

    @property_hash[:domain] = domain
    @property_hash[:description] = desc
    @property_hash[:enabled] = enabled
    @property_hash[:email] = email
    @property_hash[:project] = project
    @property_hash[:password] = pwd

    args = []
    args += ['--domain', domain] if domain
    args += ['--description', desc] if desc
    args += ['--email', email] if email
    args += ['--project', project] if project
    args += ['--password', pwd] if pwd
    args << if [true, :true].include?(enabled)
              '--enable'
            else
              '--disable'
            end
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

  def project=(proj)
    @property_flush[:project] = proj
  end

  def password
    name      = @resource[:name]
    project   = @resource.value(:project)
    pwd       = @resource.value(:password)
    user_role = @resource.value(:assignments)

    os_project_name = user_role.empty? ? project : user_role[0]

    args = ['--os-username', name]
    args += ['--os-project-name', os_project_name]
    args += ['--os-password', pwd]
    args += ['-f', 'json']

    token = self.class.openstack_caller('token', 'issue', *args)
    return nil unless token
    pwd
  end

  def password=(pwd)
    @property_flush[:password] = pwd
  end

  def flush
    return if @property_flush.empty?
    args = []
    name    = @resource[:name]
    desc    = @resource.value(:description)
    email   = @resource.value(:email)
    pwd     = @resource.value(:password)
    project = @resource.value(:project)

    args << if @property_flush[:enabled] == :true
              '--enable'
            else
              '--disable'
            end
    args += ['--password', pwd] if @property_flush[:password]
    args += ['--email', email] if @property_flush[:email]
    args += ['--description', desc] if @property_flush[:description]
    args += ['--project', project] if @property_flush[:project]

    @property_flush.clear

    return if args.empty?
    args << name
    self.class.provider_set(*args)
  end
end
