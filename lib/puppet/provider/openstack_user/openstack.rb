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
    get_list_array(provider_subcommand)
  end

  #   {
  #   "password_expires_at": null,
  #   "enabled": true,
  #   "domain_id": "bdbb92f04f2d40b284b042a27b90500b",
  #   "id": "cf6ad310ef0d471a9aae6a679e9f285e",
  #   "options": {},
  #   "name": "heat_domain_admin"
  # }
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
    user_name = entity['name']

    # project
    project_id = entity['project'] unless entity['project'].to_s.empty?
    project_id_domain = project_instances[project_id]['domain'] if project_id
    project_domain = project_id_domain || entity['project_domain']

    # domain
    domain_id = entity['domain_id'] || entity['domain']
    domain_name = if domain_id == 'default'
                    'default'
                  else
                    domain_instances[domain_id]
                  end

    entity_name = (domain_id == 'default') ? user_name : "#{domain_name}/#{user_name}"

    # [<domain>/]<user>
    @instances << new(name: entity_name,
                      ensure: :present,
                      id: entity['id'],
                      domain: domain_name,
                      user_name: user_name,
                      description: entity['description'],
                      enabled: entity['enabled'].to_s.to_sym,
                      email: entity['email'],
                      project: project_id,
                      project_domain: project_domain,
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
    domain         = @resource.value(:domain)
    user_name      = @resource.value(:user_name)
    desc           = @resource.value(:description)
    enabled        = @resource.value(:enabled)
    email          = @resource.value(:email)          unless @resource.value(:email).to_s.empty?
    project        = @resource.value(:project)        unless @resource.value(:project).to_s.empty?
    project_domain = @resource.value(:project_domain) unless @resource.value(:project_domain).to_s.empty?
    pwd            = @resource.value(:password)
    name           = (domain == 'default') ? user_name : "#{domain}/#{user_name}"

    @property_hash[:name] = name
    @property_hash[:domain] = domain
    @property_hash[:user_name] = user_name
    @property_hash[:description] = desc
    @property_hash[:enabled] = enabled
    @property_hash[:email] = email
    @property_hash[:password] = pwd

    args = []

    if project
      @property_hash[:project] = project
      args += ['--project', project]

      if project_domain
        @property_hash[:project_domain] = project_domain
        args += ['--project-domain', project_domain]
      end
    end

    args += ['--domain', domain] if domain
    args += ['--description', desc] if desc
    args += ['--email', email] if email
    args += ['--password', pwd] if pwd
    args << if enabled == :true
              '--enable'
            else
              '--disable'
            end
    args << user_name

    cmdout = self.class.provider_create(*args)

    return if cmdout == false

    if cmdout.is_a?(Hash)
      if project
        cmdout['project'] = project
        cmdout['project_domain'] = project_domain if project_domain
      end
      cmdout['description'] = desc if desc
      cmdout['email'] = email if email
      self.class.add_instance(cmdout)
    end

    @property_hash[:ensure] = :present
  end

  def destroy
    user = @property_hash[:id]

    return if self.class.provider_delete(user) == false
    self.class.delete_instance(user)

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

  def user_role_instances
    self.class.provider_instances(:openstack_user_role)
  end

  def password
    user_name = @resource.value(:user_name)
    domain    = @resource.value(:domain)
    user_id   = @property_hash[:id]
    pwd       = @resource.value(:password)

    user_role_project = user_role_instances.select { |a| a.user == user_id }
                                           .map { |a| prop_to_array(a.project) }.flatten

    user_role_domain = user_role_instances.select { |a| a.user == user_id }
                                          .map { |a| prop_to_array(a.domain) }.flatten

    # get token for first  assigned domain
    os_project_id = user_role_project.empty? ? '' : user_role_project[0]

    os_domain_id = user_role_domain.empty? ? '' : user_role_domain[0]

    # if os_domain_id is empty - use user domain name as defined in resource
    os_domain_name = user_role_domain.empty? ? domain : ''

    args = ['--os-username', user_name]
    args += ['--os-project-name', '']
    if os_project_id == ''
      args += ['--os-project-id', '']
      args += ['--os-user-domain-name', os_domain_name]
      args += ['--os-user-domain-id', os_domain_id]
    else
      args += ['--os-project-id', os_project_id]
    end
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
    user_name      = @resource.value(:user_name)
    domain         = @resource.value(:domain)
    desc           = @resource.value(:description)
    email          = @resource.value(:email)
    pwd            = @resource.value(:password)
    project        = @resource.value(:project)
    project_domain = @resource.value(:project_domain)

    args << '--enable' if @property_flush[:enabled] == :true
    args << '--disable' if @property_flush[:enabled] == :false

    args += ['--password', pwd] if @property_flush[:password]
    args += ['--email', email] if @property_flush[:email]
    args += ['--description', desc] if @property_flush[:description]
    if @property_flush[:project]
      args += ['--project', project]
      args += ['--project-domain', project_domain] unless project_domain.to_s.empty?
    end

    @property_flush.clear

    return if args.empty?

    args += ['--domain', domain]
    args << user_name

    self.class.provider_set(*args)
  end
end
