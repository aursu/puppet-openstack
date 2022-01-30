$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customtype'

Puppet::Type.newtype(:openstack_service) do
  extend CustomComm
  include CustomType

  @doc = <<-PUPPET
    @summary
      A service is an OpenStack web service that you can access through a URL, i.e. an endpoint.
    PUPPET

  ensurable

  newparam(:name) do
    desc 'The service name.'
  end

  newparam(:id) do
    desc 'The UUID of the service to which the endpoint belongs.'
  end

  newproperty(:type) do
    desc 'The service type, which describes the API implemented by the service.'

    newvalues('identity', 'image', 'compute', 'placement', 'network', 'volume',
    'volumev2', 'volumev3', 'share', 'sharev2', 'object-store',
    'orchestration', 'cloudformation', 'placement', 'load-balancer')
  end

  newproperty(:description) do
    desc 'The service description.'

    defaultto do
      service_type = @resource[:type]
      "OpenStack #{service_type} service"
    end
  end

  newproperty(:enabled) do
    desc 'Defines whether the service and its endpoints appear in the service catalog'

    newvalues(:true, :false)
    defaultto :true
  end
end
