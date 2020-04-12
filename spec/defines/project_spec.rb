require 'spec_helper'

describe 'openstack::project' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }

    openstack_network { 'provider':
      ensure                => present,
      shared                => true,
      external              => true,
      provider_network_type => 'flat',
    }
    PRECOND
  end
  let(:title) { 'service' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_openstack_project('service')
          .with(
            'ensure' => :present,
            'domain' => 'default',
            'description' => 'OpenStack service project',
            # authentication
            'auth_project_domain_name' => 'default',
          )
      }
    end
  end
end
