$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'

Puppet::Type.newtype(:openstack_project) do
  @doc = <<-PUPPET
    @summary
      A project is a group of zero or more users. In Compute, a project owns
      virtual machines. In Object Storage, a project owns containers. Users can
      be associated with more than one project.
    PUPPET

  extend OpenstackCustomComm
  # add instances() method
  include CustomType

  ensurable

  newparam(:name, namevar: true) do
    desc 'Project name'
  end

  newparam(:id) do
    desc 'Project ID (read only)'
  end

  newproperty(:domain) do
    desc 'Domain owning the project (name or ID)'
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
end
