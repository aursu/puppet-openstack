require 'spec_helper'

describe 'openstack::controller::nova' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    class { 'openstack::controller::users': admin_pass => 'secret', }
    PRECOND
  end
  let(:params) do
    {
      nova_pass: 'secret',
      nova_dbpass: 'secret',
      placement_pass: 'secret',
      admin_pass: 'secret',
      rabbit_pass: 'secret',
      mgmt_interface_ip_address: '10.0.0.11',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
