$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'

Puppet::Type.newtype(:openstack_role) do
  include CustomType

  @doc = <<-PUPPET
    @summary
      Like most OpenStack services, keystone protects its API using role-based
      access control (RBAC).

      Users can access different APIs depending on the roles they have on a
      project, domain, or system.
    PUPPET

  ensurable

  newparam(:name) do
    desc 'New role name'
  end

  newparam(:id) do
    desc 'Role ID (read only)'
  end

  newproperty(:domain) do
    desc 'Domain the role belongs to (name or ID).'
  end
end
