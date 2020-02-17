require 'spec_helper'

describe 'openstack::user' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    class { 'openstack::controller::users': admin_pass => 'secret', }
    PRECOND
  end
  let(:title) { 'glance' }
  let(:params) do
    {
      role: 'admin',
      project: 'service',
      user_pass: 'user_secret',
      admin_pass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_exec('openstack-user-glance')
          .with_command('openstack user create --domain default --description OpenStack\ glance\ user --password user_secret glance')
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

      it {
        is_expected.to contain_exec('openstack-user-glance-role')
          .with_command('openstack role add --user glance --project service admin')
          .with_refreshonly(true)
          .that_subscribes_to('Exec[openstack-user-glance]')
          .that_requires('Openstack::Role[admin]')
          .that_requires('Openstack::Project[service]')
      }
    end
  end
end
