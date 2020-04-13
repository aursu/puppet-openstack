require 'spec_helper'

describe 'openstack::user' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    class { 'openstack::controller::users': }
    PRECOND
  end
  let(:title) { 'glance' }
  let(:params) do
    {
      role: 'admin',
      project: 'service',
      user_pass: 'user_secret',
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
