$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_security_group) do
  extend CustomComm
  include CustomType

  @doc = <<-PUPPET
    @summary
      Security groups are sets of IP filter rules that are applied to all
      project instances, which define networking access to the instance. Group
      rules are project specific; project members can edit the default rules
      for their group and add new rule sets.

      All projects have a default security group which is applied to any
      instance that has no other defined security group. Unless you change the
      default, this security group denies all incoming traffic and allows only
      outgoing traffic to your instance.

      https://docs.openstack.org/python-openstackclient/train/cli/command-objects/security-group.html
    PUPPET

  ensurable

  def self.title_patterns
    [
      [
        %r{^([^/]+)/([^/]+)$},
        [
          [:project],
          [:group_name],
        ],
      ],
      [
        %r{^([^/]+)$},
        [
          [:group_name],
        ],
      ],
    ]
  end

  newparam(:project, namevar: true) do
    desc "Owner's project (name or ID)"

    # defaultto ''

    validate do |value|
      raise ArgumentError, _('Project name or ID must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

#      next if value.to_s == ''
      next if value.to_s == 'default'

      project = resource.project_instance(value) || resource.project_resource(value)
      raise ArgumentError, _("Project #{value} must be defined in catalog or exist in OpenStack environment") unless project
    end
  end

  newparam(:group_name, namevar: true) do
    desc 'Security group name'
  end

  newparam(:name) do
    desc 'Security group name'

    defaultto do
      @resource[:project].to_s.empty? ? @resource[:group_name] : (@resource[:project] + '/' + @resource[:group_name])
    end
  end

  newproperty(:id) do
    desc 'Security group ID (read only)'
  end

  newproperty(:description) do
    desc 'Security group description'
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
  end
end
