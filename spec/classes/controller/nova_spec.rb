require 'spec_helper'

describe 'openstack::controller::nova' do
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
      nova_pass: 'secret',
      nova_dbpass: 'secret',
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

      it {
        is_expected.to contain_openstack__config('/etc/nova/nova.conf/controller')
          .that_requires('Openstack::Package[openstack-nova-api]')
          .that_notifies('Exec[nova-api_db-sync]')
          .that_notifies('Exec[nova-db-sync]')
          .that_notifies('Exec[nova-map_cell0]')
      }

      it { is_expected.to contain_group('nova') }
      it { is_expected.to contain_user('nova') }
      it { is_expected.to contain_file('/var/lib/nova') }
    end
  end
end
