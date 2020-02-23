require 'spec_helper'

describe 'openstack::controller::neutron' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    include openstack::controller::keystone
    include openstack::controller::users
    include openstack::controller::nova
    PRECOND
  end
  let(:params) do
    {
      neutron_dbpass: 'secret',
      neutron_pass: 'secret',
      metadata_secret:  'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        os_facts.merge(
          hostname: 'controller',
          stype: 'openstack',
        )
      end

      it { is_expected.to compile }
    end
  end
end
