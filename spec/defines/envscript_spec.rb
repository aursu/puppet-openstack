require 'spec_helper'

describe 'openstack::envscript' do
  let(:title) { '/etc/keystone/admin-openrc.sh' }
  let(:params) do
    {
      content: {
        'OS_AUTH_URL' => 'http://controller:35357/v3',
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
