require 'spec_helper'

describe 'openstack::neutron::core' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
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
        )
      end

      it { is_expected.to compile }
    end
  end
end
