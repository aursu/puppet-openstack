require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_image).provide(:glance, parent: Puppet::Provider::Openstack) do
  desc 'manage ports for OpenStack.'

  commands glance: 'glance', openstack: 'openstack'

  defaultfor osfamily: :redhat, operatingsystemmajrelease: ['8']

  self::BASE_PROPERTIES = %w[
    status name container_format created_at size
    disk_format updated_at visibility min_disk
    protected id file self checksum owner virtual_size
    min_ram schema
  ].freeze

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.glance_command
    openstack_command('glance')
  end

  def self.provider_subcommand
    'image'
  end

  def self.image_properties(image)
    properties = {}

    # Additional properties, whose value is always a string data type, are only
    # included in the response if they have a value.
    image.each do |key, value|
      next if self::BASE_PROPERTIES.include?(key) || %w[tags location].include?(key)
      if key == 'properties' && value.is_a?(Hash)
        properties.merge!(value.map { |k, v| [k, v.to_s] }.to_h)
        next
      end
      properties[key] = value.to_s
    end

    properties
  end

  def self.provider_list
    apiclient.api_get_list('images')
  end

  def self.provider_create(*args)
    glance_command
    openstack_caller('image-create', *args)
  end

  def self.provider_delete(*args)
    glance_command
    openstack_caller('image-delete', *args)
  end

  def self.provider_set(*args)
    glance_command
    openstack_caller('image-update', *args)
  end

  def self.provider_activate(*args)
    glance_command
    openstack_caller('image-reactivate', *args)
  end

  def self.provider_deactivate(*args)
    glance_command
    openstack_caller('image-deactivate', *args)
  end

  def self.provider_tag(*args)
    glance_command
    openstack_caller('image-tag-update', *args)
  end

  def self.provider_untag(*args)
    glance_command
    openstack_caller('image-tag-delete', *args)
  end

  def self.instances
    return @instances if @instances
    @instances = []

    provider_list.map do |entity_name, entity|
      image_enabled = entity['status'].casecmp?('active')
      tags = entity['tags'].map { |t| t.to_s }

      @instances << new(name: entity_name,
                        ensure: :present,
                        id: entity['id'],
                        enabled: image_enabled.to_s.to_sym,
                        container_format: entity['container_format'],
                        tags: tags,
                        checksum: entity['checksum'],
                        disk_format: entity['disk_format'],
                        visibility: entity['visibility'],
                        project: entity['owner'],
                        protected: entity['protected'].to_s.to_sym,
                        size: entity['size'],
                        image_properties: image_properties(entity),
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

  # usage: glance image-create [--architecture <ARCHITECTURE>]
  # [--protected [True|False]] [--name <NAME>]
  # [--instance-uuid <INSTANCE_UUID>]
  # [--min-disk <MIN_DISK>] [--visibility <VISIBILITY>]
  # [--kernel-id <KERNEL_ID>]
  # [--tags <TAGS> [<TAGS> ...]]
  # [--os-version <OS_VERSION>]
  # [--disk-format <DISK_FORMAT>]
  # [--os-distro <OS_DISTRO>] [--id <ID>]
  # [--owner <OWNER>] [--ramdisk-id <RAMDISK_ID>]
  # [--min-ram <MIN_RAM>]
  # [--container-format <CONTAINER_FORMAT>]
  # [--hidden [True|False]] [--property <key=value>]
  # [--file <FILE>] [--progress] [--store <STORE>]
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

    args += ['--container-format', container_format]
    args += ['--disk-format', disk_format]

    args += ['--min-disk', min_disk] if min_disk
    args += ['--min-ram', min_ram] if min_ram

    args += ['--file', path] if path

    args += ['--protected', 'True'] if protected == :true
    args += ['--protected', 'False'] if protected == :false

    # public, private, shared, community
    args += ['--visibility', visibility] if visibility

    image_properties.each { |k, v| args += ['--property', "#{k}=#{v}"] } if image_properties

    args += ['--tags'] + tags if tags

    args += ['--name', name]

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
    id = @property_hash[:id]

    self.class.provider_activate(stat, id)
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
    id = @property_hash[:id]
    tags = @property_hash[:tags]

    tags.each do |t|
      next if prop.include?(t)
      self.class.provider_tag(id, t)
    end

    prop.each do |t|
      next if tags.include?(t)
      self.class.provider_untag(id, t)
    end
  end

  def image_properties=(prop)
    @property_flush[:image_properties] = prop
  end

  # usage: glance image-update [--architecture <ARCHITECTURE>]
  # [--protected [True|False]] [--name <NAME>]
  # [--instance-uuid <INSTANCE_UUID>]
  # [--min-disk <MIN_DISK>] [--visibility <VISIBILITY>]
  # [--kernel-id <KERNEL_ID>]
  # [--os-version <OS_VERSION>]
  # [--disk-format <DISK_FORMAT>]
  # [--os-distro <OS_DISTRO>] [--owner <OWNER>]
  # [--ramdisk-id <RAMDISK_ID>] [--min-ram <MIN_RAM>]
  # [--container-format <CONTAINER_FORMAT>]
  # [--hidden [True|False]] [--property <key=value>]
  # [--remove-property key]
  # <IMAGE_ID>
  def flush
    return if @property_flush.empty?

    args = []

    id               = @property_hash[:id]
    image_properties = @property_hash[:image_properties]

    container_format = @resource.value(:container_format)
    disk_format      = @resource.value(:disk_format)

    visibility       = @property_flush[:visibility]

    args += ['--container-format', container_format] if @property_flush[:container_format]

    args += ['--protected', 'True'] if @property_flush[:protected] == :true
    args += ['--protected', 'False'] if @property_flush[:protected] == :false

    args += ['--disk-format', disk_format] if @property_flush[:disk_format]

    # public, private, shared, community
    args += ['--visibility', visibility] if visibility

    if @property_flush[:image_properties]
      prop = @property_flush[:image_properties]

      # remove properties
      image_properties.each do |k, _v|
        next if prop[k]
        args += ['--remove-property', k]
      end

      # set properties
      prop.each do |k, v|
        next if image_properties[k] == v
        args += ['--property', "#{k}=#{v}"]
      end
    end

    @property_flush.clear

    return if args.empty?

    args << id

    auth_args

    self.class.provider_set(*args)
  end
end
