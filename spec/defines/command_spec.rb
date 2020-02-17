require 'spec_helper'

describe 'openstack::command' do
  # Openstack::Role requires resource Package['openstack-keystone']
  # which provided by Class['openstack::controller::keystone']
  # later requires Openstack::Repository[train] which provided by Class['openstack::install']
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    PRECOND
  end
  let(:title) { 'openstack-command' }
  let(:params) do
    {
      admin_pass: 'secret',
      command: 'openstack',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_exec('openstack-command')
          .with_command('openstack')
          .with_environment(
            [
              'OS_PROJECT_DOMAIN_NAME=Default',
              'OS_USER_DOMAIN_NAME=Default',
              'OS_PROJECT_NAME=admin',
              'OS_USERNAME=admin',
              'OS_PASSWORD=secret',
              'OS_AUTH_URL=http://controller:5000/v3',
              'OS_IDENTITY_API_VERSION=3',
              'OS_IMAGE_API_VERSION=2',
            ],
          )
      }

      context 'create admin role' do
        let(:title) { 'openstack-role-admin' }
        let(:params) do
          super().merge(
            command: 'openstack role create admin',
            unless: 'openstack role show admin',
          )
        end

        it {
          is_expected.to contain_exec('openstack-role-admin')
            .with_command('openstack role create admin')
            .with_unless('openstack role show admin')
        }
      end

      context 'assign role to openstack user (refresh only)' do
        let(:title) { 'openstack-user-glance-role' }
        let(:params) do
          super().merge(
            command: 'openstack role add --user glance --project service admin',
            refreshonly: true,
          )
        end

        it {
          is_expected.to contain_exec('openstack-user-glance-role')
            .with_command('openstack role add --user glance --project service admin')
            .with_refreshonly(true)
        }
      end
    end
  end
end
