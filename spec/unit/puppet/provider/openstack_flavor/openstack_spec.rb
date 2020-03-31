require 'spec_helper'

describe Puppet::Type.type(:openstack_flavor).provider(:openstack) do
  let(:resource_name) { 'm1.xlarge8' }
  let(:resource) do
    Puppet::Type.type(:openstack_flavor).new(
      name: resource_name,
      ensure: :present,
      ram: 16384,
      disk: 10,
      vcpus: 8,
    )
  end

  let(:provider) do
    provider = subject
    provider.resource = resource
    provider
  end

  let(:openstack_version) { "openstack 4.0.0\n" }
  let(:execute_options) do
    { failonfail: false }
  end

  before(:each) do
    allow(Puppet::Util).to receive(:which).with('openstack').and_return('/usr/bin/openstack')
    allow(described_class).to receive(:which).with('openstack').and_return('/usr/bin/openstack')

    described_class.instance_variable_set('@env',
                                          'OS_PROJECT_DOMAIN_NAME' => 'Default',
                                          'OS_USER_DOMAIN_NAME' => 'Default',
                                          'OS_PROJECT_NAME' => 'admin',
                                          'OS_USERNAME' => 'admin',
                                          'OS_PASSWORD' => 'secret',
                                          'OS_AUTH_URL' => 'http://controller:5000/v3',
                                          'OS_IDENTITY_API_VERSION' => '3',
                                          'OS_IMAGE_API_VERSION' => '2')
  end

  describe 'self.instances' do
    it 'with flavor listing command' do
      expect(Puppet::Util::Execution).to receive(:execute)
        .with('/usr/bin/openstack flavor list -f json --long', execute_options)

      described_class.instances
    end
  end

  describe 'new flavor' do
    it do
      expect(Puppet::Util::Execution).to receive(:execute)
        .with('/usr/bin/openstack flavor create --ram 16384 --disk 10 --swap 0 --vcpus 8 --ephemeral 0 m1.xlarge8', execute_options)
      provider.create
    end
  end
end
