$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_image) do
  extend CustomComm
  include CustomType

  @doc = <<-PUPPET
    @summary
      Create and modify virtual machine images that are compatible with OpenStack
    PUPPET

  ensurable

  newparam(:name) do
    desc 'Image name'
  end

  newproperty(:enabled) do
    desc 'Enable port (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:container_format) do
    desc 'The stored file may be a container that contains the virtual disk. For
          example, the virtual disk may be contained in a tar file which must be
          opened before the disk can be retrieved. It’s possible, however, that
          the virtual disk is not contained in a file, but is just stored as-is
          by the Image Service.'

    defaultto 'bare'

    validate do |value|
      next if %w[ami ari aki bare docker ova ovf].include? value.to_s

      raise ArgumentError, _(<<-PUPPET)
      Container format must be ami, ari, aki, bare, docker, ova, ovf;
      default: bare
      PUPPET
    end
  end

  newproperty(:tags, array_matching: :all) do
    desc 'Image tags. Tags could be only added and not removed'

    # no removal
    def insync?(is)
      # we do not remove existing tags - therefore it is in sync if :absent
      return true if @should == [:absent]

      # all tags in @should array must be defined to be in sync
      (@should.compact - is).empty?
    end

    validate do |value|
      next if value.to_s == 'absent'
      next if value.is_a?(String)

      raise ArgumentError, _('Tags must be provided either as a string for single tag or list of strings for multiple tags.')
    end

    munge do |value|
      return :absent if value.to_s == 'absent'
      value.to_s
    end
  end

  newproperty(:image_properties) do
    desc 'Image properties. Properties could be only added and not removed'

    validate do |value|
      # allow to use :absent explicitly
      next if value.to_s == 'absent'

      # we accept only Hash of properties
      next if value.is_a?(Hash) && value.all? { |k, _v| k =~ %r{^[-a-z0-9_]+$} }

      raise ArgumentError, _('Image properties must be provided as a Hash with keys that match regexp ^[-a-z0-9_]+$')
    end

    munge do |value|
      # allow to use :absent explicitly
      return :absent if value.to_s == 'absent'

      # no type conversion - operate with strings only
      value.map { |k, v| [k, v.to_s] }.to_h
    end

    def insync?(is)
      return true if @should == [:absent]

      # @should is array of Hashes with single value
      should = @should[0]

      # all properties in @should array must be defined to be in sync
      should.all? { |k, _v| should[k] == is[k] }
    end
  end

  newparam(:checksum) do
    desc 'Image checksum (read only)'
  end

  newproperty(:disk_format) do
    desc 'The virtual disk itself has its bits arranged in some format. A
          consuming service must know what this format is before it can
          effectively use the virtual disk.'

    defaultto 'qcow2'

    validate do |value|
      next if %w[ami ari aki vhd vmdk raw qcow2 vhdx vdi iso ploop].include? value.to_s

      raise ArgumentError, _(<<-PUPPET)
      Container format must be ami, ari, aki, vhd, vmdk, raw, qcow2, vhdx, vdi, iso, ploop;
      default: qcow2
      PUPPET
    end
  end

  newproperty(:visibility) do
    desc 'Image visibility'

    # https://wiki.openstack.org/wiki/Glance-v2-community-image-visibility-design
    defaultto 'public'

    validate do |value|
      next if %w[public private shared community].include? value.to_s

      raise ArgumentError, _(<<-PUPPET)
      Container format must be public, private, shared or community;
      default: public
      PUPPET
    end
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty) do
    desc 'Default project (name or ID)'
  end

  # --project-domain
  newparam(:project_domain, parent: PuppetX::OpenStack::DomainParameter) do
    desc 'Default domain (name or ID)'
  end

  newproperty(:protected) do
    desc 'Ensure that only users with permissions can delete the image'

    newvalues(:true, :false)
    defaultto :true
  end

  newparam(:id) do
    desc 'Image ID (read only)'
  end

  newparam(:size) do
    desc 'Image size (read only)'
  end

  newparam(:min_disk) do
    desc 'Minimum disk size needed to boot image, in gigabytes'

    munge do |value|
      case value
      when String
        Integer(value)
      else
        value
      end
    end

    validate do |value|
      next if value.to_s =~ %r{^[0-9]+$}
      raise ArgumentError, _('min_disk must be provided as a number.')
    end
  end

  newparam(:min_ram) do
    desc ' Minimum RAM size needed to boot image, in megabytes'

    munge do |value|
      case value
      when String
        Integer(value)
      else
        value
      end
    end

    validate do |value|
      next if value.to_s =~ %r{^[0-9]+$}
      raise ArgumentError, _('min_disk must be provided as a number.')
    end
  end

  newparam(:file) do
    desc 'Upload image from local file'

    validate do |value|
      raise ArgumentError, _('Parameter file must be a string, not a %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _('Paths to image file must be absolute, not %{entry}') % { entry: entry } unless Puppet::Util.absolute_path?(value)
    end
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
  end
end
