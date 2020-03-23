require 'spec_helper'

describe 'openstack::cinder::storage' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    PRECOND
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
