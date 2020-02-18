require 'spec_helper'

describe 'openstack::controller::glance' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    class { 'openstack::controller::users': admin_pass => 'secret', }
    PRECOND
  end
  let(:params) do
    {
      glance_pass: 'secret',
      admin_pass: 'secret',
      glance_dbpass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_user('glance')
          .with_managehome(true)
      }

      it {
        is_expected.to contain_file('/var/lib/glance')
          .with(
            'ensure' => 'directory',
            'owner'  => 'glance',
          )
      }
    end
  end
end
