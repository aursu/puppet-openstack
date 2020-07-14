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
        %r{^([^/]+)/([^/]+)/([^/]+)$},
        [
          [:user_domain],
          [:user],
          [:role],
        ],
      ],
      [
        %r{^([^/]+)/([^/]+)$},
        [
          [:user],
          [:role],
        ],
      ],
    ]
  end

  newparam(:user_domain, namevar: true, parent: PuppetX::OpenStack::DomainParameter) do
    desc 'Include <domain> (name or ID)'
  end

  newparam(:user, namevar: true) do
    desc 'Include <user> (name or ID)'
  end

  newparam(:role, namevar: true) do
    desc 'Role to add to <project>:<user> (name or ID)'
  end

  newparam(:name) do
    desc 'Resource name'

    defaultto do
      user_role = @resource[:user] + '/' + @resource[:role]
      (@resource[:user_domain].to_s == 'default') ? user_role : (@resource[:user_domain] + '/' + user_role)
    end
  end

  newparam(:domain) do
    desc 'Include <domain> (name or ID)'
  end

  newproperty(:system) do
    desc 'System or service to grant authorization to. Currently only all is
          supported which encompasses the entire deployment system.'

    newvalues(:all, :absent)
  end

  newproperty(:project, parent: PuppetX::OpenStack::ProjectProperty, array_matching: :all) do
    desc 'Include <project> (name or ID)'

    def insync?(is)
      # is == :absent in case of non-existing roles for user
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
    (self[:user_domain].to_s == 'default') ? self[:user] : (self[:user_domain] + '/' + self[:user])
  end

  autorequire(:openstack_role) do
    self[:role]
  end

  autorequire(:openstack_domain) do
    self[:user_domain]
  end

  autorequire(:openstack_project) do
    prop_to_array(self[:project]).map { |p| project_instance(p) || project_resource(p) }.compact
                                 .map { |p| p[:name] }
  end
end
