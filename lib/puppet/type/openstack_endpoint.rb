$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'
require 'uri'

Puppet::Type.newtype(:openstack_endpoint) do
  extend CustomComm
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

  def self.title_patterns
    [
      [
        %r{^([^/]+)/([^/]+)$},
        [
          [:service_name],
          [:interface],
        ],
      ],
    ]
  end

  newparam(:service_name, namevar: true) do
    desc 'The name of the service to which the endpoint belongs.'
  end

  newparam(:interface, namevar: true) do
    desc 'The interface type, which describes the visibility of the endpoint.'

    newvalues('public', 'internal', 'admin')
  end

  newparam(:name) do
    desc 'Endpoint title'

    defaultto do
      service_name = @resource[:service_name].to_s
      interface    = @resource[:interface]

      "#{service_name}/#{interface}"
    end
  end

  newparam(:id) do
    desc 'Endpoint ID (read only)'
  end

  newproperty(:region) do
    desc 'The ID of the region that contains the service endpoint.'
  end

  newparam(:url) do
    desc 'The endpoint URL.'

    validate do |value|
      unless value.match?(URI.regexp(%w[http https]))
        raise ArgumentError, "Invalid endpoint URL: #{value}"
      end
    end
  end

  newproperty(:enabled) do
    desc 'Enable project (default)'

    newvalues(:true, :false)
    defaultto :true
  end

  autorequire(:openstack_service) do
    rv = []
    rv << self[:service_name] if self[:service_name]
    rv
  end

  validate do
    if self[:url].nil? || self[:url].empty?
      raise Puppet::Error, _('The endpoint URL is required.')
    end
  end
end
