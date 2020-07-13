require 'spec_helper'

describe 'openstack::controller::heat' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    include openstack::controller::keystone
    include openstack::controller::users
    PRECOND
  end
  let(:params) do
    {
      heat_pass: 'secret',
      heat_dbpass: 'secret',
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
