require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_user_role).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'Manage role assignments for OpenStack.'

  # Generates method for all properties of the property_hash
  mk_resource_methods

  commands openstack: 'openstack'

  def self.provider_subcommand
    'role'
  end

  def self.provider_list
    get_list_array('role assignment', false)
  end

  def self.provider_create(*args)
    openstack_caller(provider_subcommand, 'add', *args)
  end

  def self.provider_delete(*args)
    openstack_caller(provider_subcommand, 'remove', *args)
  end

  def self.user_instances
    provider_instances(:openstack_user).map { |u| [u.id, { 'name' => u.user_name, 'domain' => u.domain }] }.to_h
  end

  def self.role_instances
    provider_instances(:openstack_role).map { |r| [r.id, r.name] }.to_h
  end

  def self.instances
    return @instances if @instances
    @instances = []

    openstack_command

    user_role_list = {}

    provider_list.each do |entity|
      user_id    = entity['user']
      role_id    = entity['role']
      project_id = entity['project']

      # in case if group
      next if user_id.to_s.empty?
      next unless user_instances[user_id]

      user_name = user_instances[user_id]['name']
      user_domain = user_instances[user_id]['domain']
      role_name = role_instances[role_id]

      # in case of error
      next unless user_name && role_name

      user_role_name = "#{user_name}/#{role_name}"
      entity_name = (user_domain.to_s == 'default') ? user_role_name : "#{user_domain}/#{user_role_name}"

      user_role = if user_role_list[entity_name]
                    user_role_list[entity_name]
                  else
                    {
                      'system' => [],
                      'domain' => [],
                      'project' => [],
                      'user' => user_id,
                      'user_domain' => user_domain,
                      'role' => role_id,
                    }
                  end

      %w[system domain project].each { |id| user_role[id] << entity[id] unless entity[id].to_s.empty? }

      unless project_id.to_s.empty?
        project_domain = project_instances[project_id]['domain']
        user_role['project_domain'] = project_domain unless user_role['project_domain']
      end

      user_role_list[entity_name] = user_role
    end

    user_role_list.map do |entity_name, entity|
      %w[system domain project].each { |id| entity[id] = nil if entity[id].empty? }
      entity['system'] = :all if entity['system']

      @instances << new(name: entity_name,
                        ensure: :present,
                        user: entity['user'],
                        user_domain: entity['user_domain'],
                        role: entity['role'],
                        system: entity['system'],
                        project: entity['project'],
                        project_domain: entity['project_domain'],
                        domain: entity['domain'],
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
    user           = @resource.value(:user)
    user_domain    = @resource.value(:user_domain)
    role           = @resource.value(:role)
    system         = @resource.value(:system)
    project        = @resource.value(:project)
    project_domain = @resource.value(:project_domain)
    domain         = @resource.value(:domain)

    @property_hash[:user] = user
    @property_hash[:role] = role

    project_domain_args = project_domain.to_s.empty? ? [] : ['--project-domain', project_domain]

    # openstack role add
    # --system <system> | --domain <domain> | --project <project> [--project-domain <project-domain>]
    # --user <user> [--user-domain <user-domain>] | --group <group> [--group-domain <group-domain>]
    # --role-domain <role-domain>
    # --inherited
    # <role>

    prop_to_array(system).each do |_s|
      next if self.class.provider_create('--system', 'all', '--user', user, '--user-domain', user_domain, role) == false
      @property_hash[:system] = :all
      break
    end

    domain_prop = []
    prop_to_array(domain).each do |d|
      next if self.class.provider_create('--domain', d, '--user', user, '--user-domain', user_domain, role) == false
      domain_prop << d
    end
    @property_hash[:domain] = domain_prop unless domain_prop.empty?

    project_prop = []
    prop_to_array(project).each do |p|
      args = ['--project', p] + project_domain_args + ['--user', user, '--user-domain', user_domain, role]
      next if self.class.provider_create(*args) == false
      project_prop << p
    end
    @property_hash[:project] = project_prop unless project_prop.empty?

    @property_hash[:ensure] = :present
  end

  def destroy
    user           = @resource.value(:user)
    user_domain    = @resource.value(:user_domain)
    role           = @resource.value(:role)
    system         = @resource.value(:system)
    project        = @resource.value(:project)
    project_domain = @resource.value(:project_domain)
    domain         = @resource.value(:domain)

    project_domain_args = project_domain.to_s.empty? ? [] : ['--project-domain', project_domain]

    # openstack role remove
    # --system <system> | --domain <domain> | --project <project> [--project-domain <project-domain>]
    # --user <user> [--user-domain <user-domain>] | --group <group> [--group-domain <group-domain>]
    # --role-domain <role-domain>
    # --inherited
    # <role>

    prop_to_array(system).each do |_s|
      self.class.provider_delete('--system', 'all', '--user', user, '--user-domain', user_domain, role)
      break
    end

    prop_to_array(domain).each do |d|
      self.class.provider_delete('--domain', d, '--user', user, '--user-domain', user_domain, role)
    end

    prop_to_array(project).each do |p|
      args = ['--project', p] + project_domain_args + ['--user', user, '--user-domain', user_domain, role]
      self.class.provider_delete(*args)
    end

    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  def system=(assign)
    user        = @resource.value(:user)
    user_domain = @resource.value(:user_domain)
    role        = @resource.value(:role)

    if prop_to_array(assign).empty?
      self.class.provider_delete('--system', 'all', '--user', user, '--user-domain', user_domain, role)
      @property_hash[:system] = nil
    else
      self.class.provider_create('--system', 'all', '--user', user, '--user-domain', user_domain, role)
      @property_hash[:system] = :all
    end
  end

  def project=(assign)
    user           = @resource.value(:user)
    user_domain    = @resource.value(:user_domain)
    role           = @resource.value(:role)
    project_domain = @resource.value(:project_domain)

    project_domain_args = project_domain.to_s.empty? ? [] : ['--project-domain', project_domain]

    is = prop_to_array(@property_hash[:project])
    assign = prop_to_array(assign)

    (assign - is).each do |p|
      args = ['--project', p] + project_domain_args + ['--user', user, '--user-domain', user_domain, role]
      next if self.class.provider_create(*args) == false
      is << p
    end

    (is - assign).each do |p|
      args = ['--project', p] + project_domain_args + ['--user', user, '--user-domain', user_domain, role]
      self.class.provider_delete(*args)
    end

    @property_hash[:project] = assign
  end
end
