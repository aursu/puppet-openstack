Puppet::Type.newtype(:openstack_user) do
  @doc = <<-PUPPET
    @summary
      A project is a group of zero or more users. In Compute, a project owns
      virtual machines. In Object Storage, a project owns containers. Users can
      be associated with more than one project.
    PUPPET

  ensurable

  newparam(:name, namevar: true) do
    desc 'New user name'
  end

  newparam(:id) do
    desc 'User ID (read only)'
  end

  newproperty(:domain) do
    desc 'Default domain (name or ID)'
    defaultto 'default'
  end

  newproperty(:description) do
    desc 'Project description'
  end

  newproperty(:enabled) do
    desc 'Enable project (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:email) do
    desc 'Set user email address'
    defaultto ''
  end

  newproperty(:project) do
    desc 'Default project (name or ID)'
    defaultto ''

    def insync?(_is)
      p = resource.project_instance(@should)
      return false if p.nil?

      true
    end
  end

  newparam(:assignments) do
    desc 'Project assignments (read only)'
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

  def project_instance(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id

    instances = Puppet::Type.type(:openstack_project).instances
                            .select { |resource| resource[:name] == lookup_id || resource[:id] == lookup_id }
    return nil if instances.empty?
    # no support for multiple OpenStack domains
    instances.first
  end
end
