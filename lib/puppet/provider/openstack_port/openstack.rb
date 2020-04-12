require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_port).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'manage ports for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'port'
  end

  def self.provider_list
    get_list(provider_subcommand, 'id', false,
             '-c', 'id',
             '-c', 'fixed_ips',
             '-c', 'mac_address',
             '-c', 'name',
             '-c', 'status',
             '-c', 'device_id',
             '-c', 'network_id',
             '-c', 'is_port_security_enabled')
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

    provider_list.map do |entity_id, entity|
      entity_name = entity['name'].to_s
      entity_name = "port-#{entity_id}" if entity_name.empty?

      port_enabled = entity['status'].to_s.casecmp?('active')

      new(name: entity_name,
          ensure: :present,
          real_name: entity['name'].to_s,
          id: entity_id,
          network: entity['network_id'],
          description: entity['description'],
          enabled: port_enabled.to_sym,
          port_security: entity['is_port_security_enabled'].to_s.to_sym,
          device_id: entity['device_id'],
          mac_address: entity['mac_address'],
          fixed_ips: entity['fixed_ip_addresses'],
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

  # openstack port create
  # --network <network>
  # [--description <description>]
  # [--fixed-ip subnet=<subnet>,ip-address=<ip-address> | --no-fixed-ip]
  # [--device <device-id>]
  # [--device-owner <device-owner>]
  # [--vnic-type <vnic-type>]
  # [--binding-profile <binding-profile>]
  # [--host <host-id>]
  # [--enable | --disable]
  # [--enable-uplink-status-propagation | --disable-uplink-status-propagation]
  # [--mac-address <mac-address>]
  # [--security-group <security-group> | --no-security-group]
  # [--dns-domain <dns-domain>]
  # [--dns-name <dns-name>]
  # [--allowed-address ip-address=<ip-address>[,mac-address=<mac-address>]]
  # [--qos-policy <qos-policy>]
  # [--project <project> [--project-domain <project-domain>]]
  # [--enable-port-security | --disable-port-security]
  # [--tag <tag> | --no-tag]
  # <name>

  def create
    name    = @resource[:name]
    network = @resource.value(:network)
    desc    = @resource.value(:description)
    enabled = @resource.value(:enabled)
    port_security = @resource.value(:port_security)
    device_id = @resource.value(:device_id)

    @property_hash[:real_name] = name
    @property_hash[:network] = network
    @property_hash[:description] = desc
    @property_hash[:enabled] = enabled
    @property_hash[:port_security] = port_security
    @property_hash[:device_id] = device_id

    args = []
    args += ['--network', network]
    args += ['--description', desc] if desc
    args << '--enable' if enabled == :true
    args << '--disable' if enabled == :false
    args << '--enable-port-security' if port_security == :true
    args << '--disable-port-security' if port_security == :false
    args += ['--device', device_id] if device_id

    args << name

    auth_args

    self.class.provider_create(*args)

    @property_hash[:ensure] = :present
  end

  def destroy
    id = @resource.value(:id)

    self.class.provider_delete(id)

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

  def port_security=(stat)
    @property_flush[:port_security] = stat
  end

  def device_id=(id)
    @property_flush[:device_id] = id
  end

  # usage: openstack port set [-h] [--description <description>]
  # [--device <device-id>] [--mac-address <mac-address>]
  # [--device-owner <device-owner>]
  # [--vnic-type <vnic-type>] [--host <host-id>]
  # [--dns-domain dns-domain] [--dns-name <dns-name>]
  # [--fixed-ip subnet=<subnet>,ip-address=<ip-address>]
  # [--no-fixed-ip]
  # [--binding-profile <binding-profile>]
  # [--no-binding-profile] [--qos-policy <qos-policy>]
  # [--security-group <security-group>]
  # [--no-security-group]
  # [--enable-port-security | --disable-port-security]
  # [--allowed-address ip-address=<ip-address>[,mac-address=<mac-address>]]
  # [--no-allowed-address]
  # [--data-plane-status <status>] [--tag <tag>]
  # [--no-tag]
  # <port>

  def flush
    real_name = @property_hash[:real_name]
    return if @property_flush.empty? && !real_name.to_s.empty?

    args = []
    name      = @resource[:name]
    id        = @resource.value(:id)
    desc      = @resource.value(:description)
    device_id = @resource.value(:device_id)

    args << '--enable' if @property_flush[:enabled] == :true
    args << '--disable' if @property_flush[:enabled] == :false

    args += ['--description', desc] if @property_flush[:description]

    args << '--enable-port-security' if @property_flush[:port_security] == :true
    args << '--disable-port-security' if @property_flush[:port_security] == :false

    args += ['--name', name] if real_name.to_s.empty?

    args += ['--device', device_id] if @property_flush[:device_id]

    @property_flush.clear

    return if args.empty?

    args << id

    auth_args

    self.class.provider_set(*args)
  end
end
