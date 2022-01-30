require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_security_rule).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'Manage role assignments for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'security group rule'
  end

  def self.provider_list
    apiclient.req_params = {}
    apiclient.api_get_list_array('security-group-rules', 'security_group_rules')
  end

  def self.provider_create(*args)
    @prefetch_done = false
    openstack_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    @prefetch_done = false
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.group_instances
    provider_instances(:openstack_security_group).map { |g| [g.id, { 'name' => g.group_name, 'project' => g.project }] }.to_h
  end

  def self.group_lookup(project, group_name)
    return nil unless group_name

    result = group_instances.find { |_id, group| group['project'] == project && group['name'] == group_name }

    return nil unless result
    result[0]
  end

  def self.port_range(entity)
    port_range_min = entity['port_range_min']
    port_range_max = entity['port_range_max']
    proto = entity['protocol']

    if ['icmp', 'icmpv6', 'ipv6-icmp', '1', '58'].include?(proto)
      port_range = ''
      port_range += 'type=' + port_range_min.to_s if port_range_min
      port_range += ':code=' + port_range_max.to_s if port_range_max
    elsif port_range_min || port_range_max
      port_range_min = port_range_max unless port_range_min
      port_range_max = port_range_min unless port_range_max
      port_range = "#{port_range_min}:#{port_range_max}"
    end
    port_range = 'any' if port_range.to_s.empty?
    
    port_range
  end

  def self.instances 
    return @instances if @instances && @prefetch_done
    # reset it
    @instances = []

    openstack_command

    provider_list.each do |entity|
      group_id = entity['security_group_id']

      # group could be just created or deleted therefore not existing in group_instances
      next unless group_instances[group_id]

      project_name = group_instances[group_id]['project']

      group_name = group_instances[group_id]['name']
      group_project_name = project_name.empty? ? group_name : "#{project_name}/#{group_name}"

      direction = entity['direction']

      proto = entity['protocol']
      proto = 'any' if proto.to_s.empty?

      remote = entity['remote_ip_prefix']

      range = port_range(entity)

      entity_name = "#{group_project_name}/#{direction}/#{proto}/#{remote}/#{range}"

      # [<project>/]<group>/<direction>/<proto>/<remote>/<range>

      @instances << new(name: entity_name,
                        ensure: :present,
                        id: entity['id'],
                        project: project_name,
                        group: group_name,
                        direction: direction.to_sym,
                        protocol: proto,
                        ethertype: entity['ethertype'],
                        remote_ip: remote,
                        remote_group: entity['remote_group_id'],
                        port_range: range,
                        provider: name)
    end

    @prefetch_done = true
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

  # openstack security group rule create
  # [--remote-ip <ip-address> | --remote-group <group>]
  # [--dst-port <port-range> | [--icmp-type <icmp-type> [--icmp-code <icmp-code>]]]
  # [--protocol <protocol>]
  # [--ingress | --egress]
  # [--ethertype <ethertype>]
  # [--project <project> [--project-domain <project-domain>]]
  # [--description <description>]
  # <group>

  def create
    ip_address        = @resource.value(:remote_ip)
    remote_group_name = @resource.value(:remote_group)
    port_range        = @resource.value(:port_range)
    proto             = @resource.value(:protocol)
    direction         = @resource.value(:direction)
    project           = @resource.value(:project)
    group_name        = @resource.value(:group)
    desc              = @resource.value(:description)
    ethertype         = @resource.value(:ethertype)

    group             = self.class.group_lookup(project, group_name)
    unless group
      Puppet.warning("Could not find security group ID for group name '#{group_name}' and project '#{project}'.")
      return
    end

    remote_group = self.class.group_lookup(project, remote_group_name)

    project    = nil if project.to_s.empty?
    port_range = nil if ['', 'any'].include? port_range.to_s
    proto      = nil if ['', 'any'].include? proto.to_s

    if port_range
      port_range_min, port_range_max = port_range.split(':')
      _tag, icmp_type = port_range_min.split('=')
      _tag, icmp_code = port_range_max.split('=') if port_range_max && icmp_type
    end

    @property_hash[:group] = group_name
    @property_hash[:remote_group] = remote_group_name if remote_group_name
    @property_hash[:remote_ip] = ip_address if ip_address
    @property_hash[:port_range] = port_range if port_range
    @property_hash[:protocol] = proto if proto
    @property_hash[:direction] = direction if direction
    @property_hash[:project] = project if project
    @property_hash[:description] = desc if desc
    @property_hash[:ethertype] = ethertype if ethertype

    args = []
    # [--remote-ip <ip-address> | --remote-group <group>]
    if remote_group
      args += ['--remote-group', remote_group]
    elsif ip_address
      args += ['--remote-ip', ip_address]
    end

    # [--dst-port <port-range> | [--icmp-type <icmp-type> [--icmp-code <icmp-code>]]]
    if port_range
      if icmp_type
        args += ['--icmp-type', icmp_type]
        args += ['--icmp-code', icmp_code] if icmp_code
      else
        args += ['--dst-port', port_range]
      end
    end

    # [--protocol <protocol>]
    args += ['--protocol', proto] if proto

    # [--ingress | --egress]
    args << if direction.to_s == 'egress'
              '--egress'
            else
              '--ingress'
            end

    # [--project <project> [--project-domain <project-domain>]]
    args += ['--project', project] if project

    args += ['--description', desc] if desc
    args += ['--ethertype', ethertype] if ethertype
    args << group

    auth_args

    self.class.provider_create(*args)

    @property_hash[:ensure] = :present
  end

  def destroy
    rule_id = @property_hash[:id]

    self.class.provider_delete(rule_id)

    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end
end
