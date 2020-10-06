require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_image).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'manage ports for OpenStack.'

  commands openstack: 'openstack'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'image'
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

  def self.provider_show(*args)
    openstack_caller(provider_subcommand, 'show', *args)
  end

  def self.instances
    return @instances if @instances
    @instances = []

    openstack_command

    provider_list.map do |entity_name, entity|
      image_enabled = entity['status'].casecmp?('active')

      @instances << new(name: entity_name,
                        ensure: :present,
                        id: entity['id'],
                        enabled: image_enabled.to_s.to_sym,
                        container_format: entity['container_format'],
                        tags: entity['tags'],
                        checksum: entity['checksum'],
                        disk_format: entity['disk_format'],
                        visibility: entity['visibility'],
                        project: entity['project'],
                        protected: entity['protected'].to_s.to_sym,
                        size: entity['size'],
                        provider: name)
    end

    @instances
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

  def provider_show
    return @desc if @desc

    image_id = @property_hash[:id]
    return {} unless image_id

    args = ['-f', 'json', image_id]
    cmdout = self.class.provider_show(*args)
    return {} if cmdout.nil?

    @desc = JSON.parse(cmdout).map { |k, v| [k.downcase.tr(' ', '_'), v] }.to_h
  end

  def image_properties
    desc = provider_show

    properties = desc['properties']
    return {} unless properties

    properties.map { |k, v| [k, v.to_s] }.to_h
  end

  # usage: openstack image create [-f {json,shell,table,value,yaml}]
  # [--prefix PREFIX] [--id <id>]
  # [--container-format <container-format>]
  # [--disk-format <disk-format>]
  # [--min-disk <disk-gb>] [--min-ram <ram-mb>]
  # [--file <file> | --volume <volume>] [--force]
  # [--sign-key-path <sign-key-path>]
  # [--sign-cert-id <sign-cert-id>]
  # [--protected | --unprotected]
  # [--public | --private | --community | --shared]
  # [--property <key=value>] [--tag <tag>]
  # [--project <project>]
  # [--project-domain <project-domain>]
  # <image-name>
  def create
    name             = @resource[:name]
    container_format = @resource.value(:container_format)
    disk_format      = @resource.value(:disk_format)
    min_disk         = @resource.value(:min_disk)
    min_ram          = @resource.value(:min_ram)
    path             = @resource.value(:file)
    protected        = @resource.value(:protected)
    visibility       = @resource.value(:visibility)
    image_properties = @resource.value(:image_properties)
    tags             = @resource.value(:tags)
    project          = @resource.value(:project)
    project_domain   = @resource.value(:project_domain)

    unless path && File.exist?(path)
      warning _('Image file is not specified or does not exist')
      @property_hash[:ensure] = :absent
      return
    end

    @property_hash[:name] = name
    @property_hash[:container_format] = container_format
    @property_hash[:disk_format] = disk_format
    @property_hash[:protected] = protected
    @property_hash[:visibility] = visibility
    @property_hash[:image_properties] = image_properties
    @property_hash[:tags] = tags

    args = []
    if project
      @property_hash[:project] = project
      args += ['--project', project]

      if project_domain
        @property_hash[:project_domain] = project_domain
        args += ['--project-domain', project_domain]
      end
    end

    args += ['--container-format', container_format]
    args += ['--disk-format', disk_format]

    args += ['--min-disk', min_disk] if min_disk
    args += ['--min-ram', min_ram] if min_ram

    args += ['--file', path] if path

    args << '--protected' if protected == :true
    args << '--unprotected' if protected == :false

    # public, private, shared, community
    args << "--#{visibility}" if visibility

    image_properties.each { |k, v| args += ['--property', "#{k}=#{v}"] } if image_properties
    tags.each { |t| args += ['--tag', t] } if tags

    args << name

    auth_args

    self.class.provider_create(*args)

    @property_hash[:ensure] = :present
  end

  def destroy
    id = @property_hash[:id]

    self.class.provider_delete(id)

    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  def container_format=(format)
    @property_flush[:container_format] = format
  end

  def enabled=(stat)
    @property_flush[:enabled] = stat
  end

  def protected=(stat)
    @property_flush[:protected] = stat
  end

  def disk_format=(format)
    @property_flush[:disk_format] = format
  end

  def visibility=(stat)
    @property_flush[:visibility] = stat
  end

  def tags=(prop)
    @property_flush[:tags] = prop
  end

  def project=(proj)
    @property_flush[:project] = proj
  end

  def image_properties=(prop)
    @property_flush[:image_properties] = prop
  end

  # openstack image set [-h] [--name <name>] [--min-disk <disk-gb>]
  # [--min-ram <ram-mb>]
  # [--container-format <container-format>]
  # [--disk-format <disk-format>]
  # [--protected | --unprotected]
  # [--public | --private | --community | --shared]
  # [--property <key=value>] [--tag <tag>]
  # [--architecture <architecture>]
  # [--instance-id <instance-id>]
  # [--kernel-id <kernel-id>] [--os-distro <os-distro>]
  # [--os-version <os-version>]
  # [--ramdisk-id <ramdisk-id>]
  # [--deactivate | --activate] [--project <project>]
  # [--project-domain <project-domain>]
  # [--accept | --reject | --pending]
  # <image>
  def flush
    return if @property_flush.empty?

    args = []

    name             = @resource[:name]
    project          = @resource.value(:project)
    project_domain   = @resource.value(:project_domain)
    container_format = @resource.value(:container_format)
    disk_format      = @resource.value(:disk_format)
    visibility       = @resource.value(:visibility)
    tags             = @resource.value(:tags)
    image_properties = @resource.value(:image_properties)

    args += ['--container-format', container_format] if @property_flush[:container_format]

    args << '--activate' if @property_flush[:enabled] == :true
    args << '--deactivate' if @property_flush[:enabled] == :false

    args << '--protected' if @property_flush[:protected] == :true
    args << '--unprotected' if @property_flush[:protected] == :false

    args += ['--disk-format', disk_format] if @property_flush[:disk_format]

    args << "--#{visibility}" if @property_flush[:visibility]

    tags.each { |t| args += ['--tag', t] } if tags && @property_flush[:tags]
    image_properties.each { |k, v| args += ['--property', "#{k}=#{v}"] } if image_properties && @property_flush[:image_properties]

    if project && @property_flush[:project]
      args += ['--project', project]
      args += ['--project-domain', project_domain] if project_domain
    end

    @property_flush.clear

    return if args.empty?

    args << name

    auth_args

    self.class.provider_set(*args)
  end
end
