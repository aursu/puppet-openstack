$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'

Puppet::Type.newtype(:openstack_domain) do
  include CustomType

  @doc = <<-PUPPET
    @summary
      Domains are high-level containers for projects, users and groups. As such,
      they can be used to centrally manage all keystone-based identity
      components. With the introduction of account domains, server, storage and
      other resources can now be logically grouped into multiple projects
      (previously called tenants) which can themselves be grouped under a
      master account-like container. In addition, multiple users can be managed
      swithin an account domain and assigned roles that vary for each project.

      https://docs.openstack.org/security-guide/identity/domains.html
    PUPPET

  ensurable

  newparam(:name, namevar: true) do
    desc 'Domain name'
  end

  newparam(:id) do
    desc 'Domain ID (read only)'
  end

  newproperty(:description) do
    desc 'Domain description'
  end

  newproperty(:enabled) do
    desc 'Enable domain (default)'

    newvalues(:true, :false)
    defaultto :true
  end
end
