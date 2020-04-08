require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_subnet).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'Manage networks for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'subnet'
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

      pools = entity['allocation_pools']

      # support for only single allocation
      # TODO: support for multiple allocations
      pool = nil
      pool = pools[0] if pools.is_a?(Array)
      pool = {} if pool.nil?

      pool_start = pool['start']
      pool_end   = pool['end']

      new(name: entity_name,
          ensure: :present,
          id: entity['id'],
          network: entity['network'],
          subnet_range: entity['subnet'],
          dns_nameserver: entity['name_servers'],
          gateway: entity['gateway'],
          project: entity['project'],
          ip_version: entity['ip_version'].to_s,
          dhcp: entity['dhcp'].to_s.to_sym,
          allocation_pool: (pool_start && pool_end),
          allocation_pool_start: pool_start,
          allocation_pool_end: pool_end,
          description: entity['description'],
          provider: name)
    end
  end

  def self.prefetch(resources)
    entities = instances
    resources.keys.each do |entity_name|
      # rubocop:disable Lint/AssignmentInCondition
      if provider = entities.find { |entity| entity.name == entity_name }
        resources[entity_name].provider = provider
      end
    end
    # rubocop:enable Lint/AssignmentInCondition
  end

  def create
    name                  = @resource[:name]
    project               = @resource.value(:project)
    subnet_range          = @resource.value(:subnet_range)
    allocation_pool       = @resource.value(:allocation_pool)
    allocation_pool_start = @resource.value(:allocation_pool_start)
    allocation_pool_end   = @resource.value(:allocation_pool_end)
    dhcp                  = @resource.value(:dhcp)

    dns_nameserver = @resource.value(:dns_nameserver)
    dns_nameserver = case dns_nameserver
                     when nil, :absent, 'absent'
                       nil
                     else
                       [dns_nameserver].flatten
                     end

    gateway               = @resource.value(:gateway)
    ip_version            = @resource.value(:ip_version)
    desc                  = @resource.value(:description)
    network               = @resource.value(:network)

    @property_hash[:project]        = project      if project
    @property_hash[:subnet_range]   = subnet_range if subnet_range
    if allocation_pool == :true && allocation_pool_start && allocation_pool_end
      @property_hash[:allocation_pool]       = :true
      @property_hash[:allocation_pool_start] = allocation_pool_start
      @property_hash[:allocation_pool_end]   = allocation_pool_end
    else
      @property_hash[:allocation_pool]       = :false
    end
    @property_hash[:dhcp]           = dhcp
    @property_hash[:dns_nameserver] = dns_nameserver if dns_nameserver
    @property_hash[:gateway]        = gateway        if gateway
    @property_hash[:ip_version]     = ip_version     if ip_version
    @property_hash[:description]    = desc           if desc
    @property_hash[:network]        = network

    args = []
    args += ['--project', project]           if project
    args += ['--subnet-range', subnet_range] if subnet_range
    if @property_hash[:allocation_pool] == :true
      args += ['--allocation-pool', "start=#{allocation_pool_start},end=#{allocation_pool_end}"]
    end
    args << '--dhcp'    if dhcp == :true
    args << '--no-dhcp' if dhcp == :false

    if dns_nameserver
      dns_nameserver.each { |ns| args += ['--dns-nameserver', ns] }
    end

    args += ['--gateway', gateway]       if gateway
    args += ['--ip-version', ip_version] if ip_version
    args += ['--description', desc]      if desc
    args += ['--network', network]
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

  def allocation_pool=(stat)
    @property_flush[:allocation_pool] = stat
  end

  def allocation_pool_start=(ip)
    @property_flush[:allocation_pool_start] = ip
  end

  def allocation_pool_end=(ip)
    @property_flush[:allocation_pool_start] = ip
  end

  def dhcp=(stat)
    @property_flush[:dhcp] = stat
  end

  def dns_nameserver=(ns)
    @property_flush[:dns_nameserver] = ns
  end

  def description=(desc)
    @property_flush[:description] = desc
  end

  def gateway=(ip)
    @property_flush[:gateway] = ip
  end

  def flush
    return if @property_flush.empty?

    name                  = @resource[:name]
    allocation_pool       = @resource.value(:allocation_pool)
    allocation_pool_start = @resource.value(:allocation_pool_start)
    allocation_pool_end   = @resource.value(:allocation_pool_end)

    dns_nameserver        = @resource.value(:dns_nameserver)
    dns_nameserver        = [dns_nameserver].flatten if dns_nameserver && dns_nameserver.to_s != 'absent'

    gateway               = @resource.value(:gateway)
    desc                  = @resource.value(:description)

    args = []

    if allocation_pool_start && allocation_pool_end
      if @property_flush[:allocation_pool] == :true
        args += ['--allocation-pool', "start=#{allocation_pool_start},end=#{allocation_pool_end}"]
      end
      if @property_flush[:allocation_pool_start] || @property_flush[:allocation_pool_end]
        args += ['--allocation-pool', "start=#{allocation_pool_start},end=#{allocation_pool_end}"] if allocation_pool
      end
    end

    args << '--no-allocation-pool' if @property_flush[:allocation_pool] == :false

    args << '--dhcp'    if @property_flush[:dhcp] == :true
    args << '--no-dhcp' if @property_flush[:dhcp] == :false

    if @property_flush[:dns_nameserver] && dns_nameserver.is_a?(Array)
      dns_nameserver.each { |ns| args += ['--dns-nameserver', ns] }
    end

    args << '--no-dns-nameserver' if @property_flush[:dns_nameserver] == :absent
    args += ['--gateway', gateway] if @property_flush[:gateway]

    args += ['--description', desc] if @property_flush[:description]

    @property_flush.clear

    return if args.empty?
    args << name
    self.class.provider_set(*args)
  end
end
