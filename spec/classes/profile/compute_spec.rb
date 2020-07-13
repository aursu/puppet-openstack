require 'spec_helper'

describe 'openstack::profile::compute' do
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
