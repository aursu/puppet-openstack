$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_user) do
  include CustomType

  @doc = <<-PUPPET
    @summary
      A project is a group of zero or more users. In Compute, a project owns
      virtual machines. In Object Storage, a project owns containers. Users can
      be associated with more than one project.
    PUPPET

  ensurable

  def self.title_patterns
    [
      [
        %r{^(([^/]+)/([^/]+))$},
        [
          [:name],
          [:domain],
          [:user_name],
        ],
      ],
      [
        %r{^(([^/]+))$},
        [
          [:name],
          [:user_name],
        ],
      ],
    ]
  end

  newparam(:name, namevar: true) do
    desc 'New user name'
  end

  newparam(:domain, parent: PuppetX::OpenStack::DomainParameter) do
    desc 'Default domain (name or ID)'
  end

  newparam(:user_name) do
    desc 'New user name'
  end

  newparam(:id) do
    desc 'User ID (read only)'
  end

  newproperty(:description) do
    desc 'User description'
  end

  newproperty(:enabled) do
    desc 'Enable user (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:email) do
    desc 'Set user email address'
    defaultto ''
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty) do
    desc 'Default project (name or ID)'
  end

  # --project-domain
  newparam(:project_domain, parent: PuppetX::OpenStack::DomainParameter) do
    desc 'Default domain (name or ID)'
  end

  newproperty(:password) do
    desc 'The password of the user.'

    def change_to_s(currentvalue, _newvalue)
      (currentvalue == :absent) ? 'created password' : 'changed password'
    end

    # rubocop:disable Style/PredicateName
    def is_to_s(_currentvalue)
      '[old password redacted]'
    end
    # rubocop:enable Style/PredicateName

    def should_to_s(_newvalue)
      '[new password redacted]'
    end
  end

  autorequire(:openstack_project) do
    rv = []
    rv << self[:project] if self[:project]
    rv
  end
end
