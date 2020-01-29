require 'spec_helper'

describe 'openstack::package' do
  let(:pre_condition) do
    <<-PRECOND
    openstack::repository { 'train':
    }
    PRECOND
  end
  let(:title) { 'openstack-keystone' }
  let(:params) do
    {
      cycle: 'train',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
