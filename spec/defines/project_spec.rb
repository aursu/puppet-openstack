require 'spec_helper'

describe 'openstack::project' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    PRECOND
  end
  let(:title) { 'service' }
  let(:params) do
    {
      admin_pass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_exec('openstack-project-service')
          .with_command('openstack project create --domain default --description OpenStack\ service\ project service')
          .with_environment(
            [
              'OS_PROJECT_DOMAIN_NAME=default',
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
    end
  end
end
