require 'spec_helper'

describe 'openstack::controller::cinder' do
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
      cinder_dbpass: 'secret',
      cinder_pass: 'secret',
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
