$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'

Puppet::Type.newtype(:openstack_service) do
  include CustomType

  @doc = <<-PUPPET
    @summary
      The process of engaging an OpenStack cloud is started through the
      querying of an API endpoint.

      OpenStack provides both public facing and private API endpoints. By
      default, OpenStack components use the publicly defined endpoints.

      https://docs.openstack.org/security-guide/api-endpoints/api-endpoint-configuration-recommendations.html
    PUPPET

  ensurable

  newparam(:name) do
    desc 'The service name.'
  end

  newparam(:id) do
    desc 'The UUID of the service to which the endpoint belongs.'
  end

  newproperty(:description) do
    desc 'The service description.'
  end

  newproperty(:enabled) do
    desc 'Defines whether the service and its endpoints appear in the service catalog'

    newvalues(:true, :false)
    defaultto :true
  end

  newproperty(:type) do
    desc 'The service type, which describes the API implemented by the service.'

    newvalues('identity', 'image', 'compute', 'placement', 'network', 'volume',
    'volumev2', 'volumev3', 'share', 'sharev2', 'object-store',
    'orchestration', 'cloudformation', 'placement', 'load-balancer')
  end
end
