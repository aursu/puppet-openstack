require 'spec_helper'

describe 'openstack::controller::networking' do
  let(:pre_condition) { 'include openstack' }

  let(:params) do
    {
      provider_network_cidr: '192.168.0.0/24',
      provider_network_gateway: '192.168.0.1',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
