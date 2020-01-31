require 'spec_helper'

describe 'openstack::config' do
  let(:title) { '/etc/keystone/keystone.conf' }
  let(:params) do
    {
      content: {
        'token/provider' => 'fernet',
      },
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
