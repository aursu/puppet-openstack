require 'spec_helper'

describe 'openstack::nova::host' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    include openstack::controller::keystone
    include openstack::controller::users
    include openstack::controller::nova
    PRECOND
  end
  let(:title) { 'compute01' }
  let(:params) do
    {}
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

      it {
        is_expected.to contain_exec('nova-discover_hosts-compute01')
          .with_command('nova-manage cell_v2 discover_hosts')
          .with_unless('nova-manage host list | grep compute01')
      }
    end
  end
end
