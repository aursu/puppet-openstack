require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_flavor).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'manage flavors for OpenStack.'

  commands openstack: 'openstack'

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def self.provider_subcommand
    'flavor'
  end

  def self.provider_list
    apiclient.req_params = { is_public: 'none' }
    apiclient.api_get_list('flavors/detail', 'flavors')
  end

  def self.provider_create(*args)
    @prefetch_done = false
    openstack_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    @prefetch_done = false
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.instances
    return @instances if @instances && @prefetch_done
    @instances = []

    openstack_command

    provider_list.map do |flavor_name, flavor|
      swap = (flavor['swap'] == '') ? 0 : flavor['swap'].to_i

      @instances << new(name: flavor_name,
                        ensure: :present,
                        ram: flavor['ram'],
                        disk: flavor['disk'],
                        ephemeral: flavor['OS-FLV-EXT-DATA:ephemeral'],
                        swap: swap,
                        vcpus: flavor['vcpus'],
                        provider: name)
    end

    @prefetch_done = true
    @instances
  end

  def self.prefetch(resources)
    flavors = instances
    # rubocop:disable Lint/AssignmentInCondition
    resources.keys.each do |name|
      if provider = flavors.find { |flavor| flavor.name == name }
        resources[name].provider = provider
      end
    end
    # rubocop:enable Lint/AssignmentInCondition
  end

  # openstack flavor create
  # [--id <id>]
  # [--ram <size-mb>]
  # [--disk <size-gb>]
  # [--ephemeral-disk <size-gb>]
  # [--swap <size-mb>]
  # [--vcpus <num-cpu>]
  # [--rxtx-factor <factor>]
  # [--public | --private]
  # [--property <key=value> [...] ]
  # [--project <project>]
  # [--project-domain <project-domain>]
  # <flavor-name>
  def create
    name       = @resource[:name]
    ram        = @resource.value(:ram)
    disk       = @resource.value(:disk)
    ephemeral  = @resource.value(:ephemeral)
    swap       = @resource.value(:swap)
    vcpus      = @resource.value(:vcpus)
    visibility = @resource.value(:visibility)

    @property_hash[:ram] = ram
    @property_hash[:disk] = disk
    @property_hash[:ephemeral] = ephemeral
    @property_hash[:swap] = swap
    @property_hash[:vcpus] = vcpus

    visibility_flag = if visibility.to_s == 'private'
                        '--private'
                      else # default
                        '--public'
                      end

    auth_args

    self.class.provider_create('--ram', ram,
                               '--disk', disk,
                               '--swap', swap,
                               '--vcpus', vcpus,
                               '--ephemeral', ephemeral,
                               visibility_flag,
                               name)

    @property_hash[:ensure] = :present

    exists? ? (return true) : (return false)
  end

  def destroy
    name = @resource[:name]

    self.class.provider_delete(name)

    @property_hash.clear
    exists? ? (return false) : (return true)
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  # openstack flavor set
  # [--no-property]
  # [--property <key=value> [...] ]
  # [--project <project>]
  # [--project-domain <project-domain>]
  # <flavor>
end
