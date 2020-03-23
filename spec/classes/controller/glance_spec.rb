require 'spec_helper'

describe 'openstack::controller::glance' do
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
      glance_pass: 'secret',
      glance_dbpass: 'secret',
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
