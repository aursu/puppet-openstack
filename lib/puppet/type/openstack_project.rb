$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_project) do
  extend CustomComm
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
        %r{^([^/]+)/([^/]+)$},
        [
          [:domain],
          [:project_name],
        ],
      ],
      [
        %r{^([^/]+)$},
        [
          [:project_name],
        ],
      ],
    ]
  end

  newparam(:domain, namevar: true, parent: PuppetX::OpenStack::DomainParameter) do
    desc 'Domain owning the project (name or ID)'
  end

  newparam(:project_name, namevar: true) do
    desc 'Project name'
  end

  newparam(:name) do
    desc 'New user name'

    defaultto do
      (@resource[:domain].to_s == 'default') ? @resource[:project_name] : (@resource[:domain] + '/' + @resource[:project_name])
    end
  end

  newparam(:id) do
    desc 'Project ID (read only)'
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
