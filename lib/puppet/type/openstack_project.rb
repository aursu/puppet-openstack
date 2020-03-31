Puppet::Type.newtype(:openstack_project) do
  @doc = <<-PUPPET
    @summary
      A project is a group of zero or more users. In Compute, a project owns
      virtual machines. In Object Storage, a project owns containers. Users can
      be associated with more than one project.
    PUPPET

  ensurable

  newparam(:name, namevar: true) do
    desc 'Project name'
  end

  newparam(:id) do
    desc 'Project ID (read only)'
  end

  newproperty(:domain) do
    desc 'Domain owning the project (name or ID)'
  end

  newproperty(:description) do
    desc 'Project description'
  end

  newparam(:enabled, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Enable project (default)'
    defaultto :true
  end

  def lookupcatalog(key)
    return nil unless catalog
    # path, subject_hash and title are all key values
    catalog.resources.find { |r| r.is_a?(Puppet::Type.type(:openstack_project)) && [r[:id], r.title].include?(key) }
  end
end
