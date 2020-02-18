require 'spec_helper'

describe 'openstack::controller::placement' do
  # placement-api is a WSGI script
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include apache
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    class { 'openstack::controller::users': admin_pass => 'secret', }
    PRECOND
  end
  let(:params) do
    {
      placement_pass: 'secret',
      admin_pass: 'secret',
      placement_dbpass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_user('placement')
          .with_managehome(true)
      }

      it {
        is_expected.to contain_file('/var/lib/placement')
          .with(
            'ensure' => 'directory',
            'owner'  => 'placement',
          )
      }
    end
  end
end
