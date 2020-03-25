require 'spec_helper'

describe 'openstack::compute::neutron' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    include openstack::compute::nova
    PRECOND
  end
  let(:params) do
    {
      neutron_pass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        os_facts.merge(
          hostname: 'compute',
          stype: 'openstack',
          virtualization_support: true,
        )
      end

      it { is_expected.to compile }
    end
  end
end
