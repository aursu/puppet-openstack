require 'spec_helper'

describe 'openstack::profile::controller' do
  let(:pre_condition) do
    <<-PRECOND
    include apache
    include openstack
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
