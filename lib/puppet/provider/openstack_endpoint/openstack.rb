require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))
require 'json'

Puppet::Type.type(:openstack_endpoint).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'Manage API endpoints for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'endpoint'
  end

  def self.provider_list
    apiclient.req_params = {}
    apiclient.api_get_list_array('endpoints')
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

  def self.service_instances
    provider_instances(:openstack_service).map { |d| [d.id, d.name] }.to_h
  end

  def self.add_instance(entity = {})
    @instances = [] unless @instances

    # interface
    interface = entity['interface']

    # service
    service_id = entity['service_id']
    service_name = service_instances[service_id]

    return unless service_name

    entity_name = "#{service_name}/#{interface}"

    # [<domain>/]<project>
    @instances << new(name: entity_name,
                      ensure: :present,
                      id: entity['id'],
                      region: entity['region_id'],
                      url: entity['url'],
                      enabled: entity['enabled'].to_s.to_sym,
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

    provider_list.each { |entity| add_instance(entity) }
    @prefetch_done = true

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
    region       = @resource.value(:region)
    service      = @resource.value(:service_name)
    interface    = @resource.value(:interface)
    url          = @resource.value(:url)
    enabled      = @resource.value(:enabled)

    @property_hash[:region] = region
    @property_hash[:service_name] = service
    @property_hash[:enabled] = enabled

    args = []
    args += ['--region', region] if region
    args << if [true, :true].include?(enabled)
              '--enable'
            else
              '--disable'
            end
    args << service
    args << interface
    args << url

    auth_args

    cmdout = self.class.provider_create(*args)

    return if cmdout == false
    self.class.add_instance(cmdout) if cmdout.is_a?(Hash)

    @property_hash[:ensure] = :present
  end

  def destroy
    endp = @property_hash[:id]

    return if self.class.provider_delete(endp) == false
    self.class.delete_instance(endp)

    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  def region=(reg)
    @property_flush[:region] = reg
  end

  def enabled=(stat)
    @property_flush[:enabled] = stat
  end

  def interface=(iface)
    @property_flush[:interface] = iface
  end

  def url=(endp_url)
    @property_flush[:url] = endp_url
  end

  def service_name=(svc)
    @property_flush[:service_name] = svc
  end

  # usage: openstack endpoint set [-h] [--region <region-id>]
  # [--interface <interface>]
  # [--url <url>]
  # [--service <service>]
  # [--enable | --disable]
  # <endpoint-id>
  def flush
    return if @property_flush.empty?
    args = []

    endp      = @property_hash[:id]
    reg       = @resource.value(:region)
    svc       = @resource.value(:service_name)
    iface     = @resource.value(:interface)
    endp_url  = @resource.value(:url)

    args << if @property_flush[:enabled] == :true
              '--enable'
            else
              '--disable'
            end
    args += ['--service', svc] if @property_flush[:service_name]
    args += ['--url', endp_url] if @property_flush[:url]
    args += ['--interface', iface] if @property_flush[:interface]
    args += ['--region', reg] if @property_flush[:region]

    @property_flush.clear

    return if args.empty?

    args << endp

    auth_args

    self.class.provider_set(*args)
  end
end
