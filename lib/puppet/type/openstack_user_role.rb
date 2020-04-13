$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_user_role) do
  include CustomType

  @doc = <<-PUPPET
    @summary
      Like most OpenStack services, keystone protects its API using role-based
      access control (RBAC).

      Users can access different APIs depending on the roles they have on a
      project, domain, or system.
    PUPPET

  ensurable

  def self.title_patterns
    [
      [
        %r{^([^/]+)/([^/]+)$},
        [
          [:user],
          [:role],
        ],
      ],
    ]
  end

  newparam(:name) do
    desc 'Resource name'
    defaultto { @resource[:user] + '/' + @resource[:role] }
  end

  newparam(:user, parent: PuppetX::OpenStack::UserProperty, namevar: true) do
    desc 'Include <user> (name or ID)'
  end

  newparam(:role, parent: PuppetX::OpenStack::RoleProperty, namevar: true) do
    desc 'Role to add to <project>:<user> (name or ID)'
  end

  newproperty(:system) do
    desc 'System or service to grant authorization to. Currently only all is
          supported which encompasses the entire deployment system.'

    newvalues(:all, :absent)
  end

  newparam(:domain) do
    desc 'Include <domain> (name or ID)'
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty, array_matching: :all) do
    desc 'Include <project> (name or ID)'

    def insync?(is)
      # is == :absent in case of non-existing subnets for router
      return @should == [:absent] if is.nil? || is == [] || is.to_s == 'absent'

      is.flatten.sort == should.flatten.sort
    end

    munge do |value|
      return :absent if value.to_s == 'absent'

      proj = resource.project_instance(value)
      value = proj[:id] if proj

      value
    end
  end

  autorequire(:openstack_user) do
    self[:user]
  end

  autorequire(:openstack_role) do
    self[:role]
  end

  autorequire(:openstack_project) do
    req = []
    req << self[:project] if self[:project]
    req.flatten
  end
end
