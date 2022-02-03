require 'spec_helper'

describe Puppet::Type.type(:openstack_flavor).provider(:openstack) do
  let(:flavors) do
    <<-OS_OUTPUT
    [
      {
        "Name": "m1.xlarge8",
        "RAM": 16384,
        "Ephemeral": 0,
        "Properties": "",
        "VCPUs": 8,
        "Swap": "",
        "Is Public": true,
        "Disk": 10,
        "RXTX Factor": 1.0,
        "ID": "7b119fd7-6307-430c-a501-a1b8dc31e308"
      }
    ]
    OS_OUTPUT
  end
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

  before(:each) do
    allow(Puppet::Util).to receive(:which).with('openstack').and_return('/usr/bin/openstack')
    allow(described_class).to receive(:which).with('openstack').and_return('/usr/bin/openstack')
    allow(described_class).to receive(:auth_env).and_return('OS_PROJECT_DOMAIN_NAME' => 'Default',
                                                            'OS_USER_DOMAIN_NAME' => 'Default',
                                                            'OS_PROJECT_NAME' => 'admin',
                                                            'OS_USERNAME' => 'admin',
                                                            'OS_PASSWORD' => 'secret',
                                                            'OS_AUTH_URL' => 'http://controller:5000/v3',
                                                            'OS_IDENTITY_API_VERSION' => '3',
                                                            'OS_IMAGE_API_VERSION' => '2')
  end

  describe 'new flavor' do
    it do
      expect(Puppet::Util::Execution).to receive(:execute)
        .with('/usr/bin/openstack flavor create --ram 16384 --disk 10 --swap 0 --vcpus 8 --ephemeral 0 --public m1.xlarge8')
      provider.create
    end
  end
end
