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

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name) do
    desc 'Security group name'
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty) do
    desc "Owner's project (name or ID)"

    validate do |value|
      next if value.to_s == ''
      next if value.to_s == 'default'

      super(value)
    end
  end

  # --project-domain
  newparam(:project_domain, parent: PuppetX::OpenStack::DomainParameter) do
    desc 'Domain the project belongs to (name or ID).'
  end

  newparam(:group_name) do
    desc 'Security group name'
  end

  newproperty(:id) do
    desc 'Security group ID (read only)'
  end

  newproperty(:description) do
    desc 'Security group description'
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] unless self[:project].to_s.empty?
    rv
  end
end
