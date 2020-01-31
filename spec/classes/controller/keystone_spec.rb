require 'spec_helper'

describe 'openstack::controller::keystone' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    openstack::repository { 'train':
    }
    PRECOND
  end
  let(:params) do
    {
      keystone_dbpass: 'secret',
      admin_pass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
