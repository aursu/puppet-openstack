require 'spec_helper'

describe 'openstack::controller::placement' do
  # placement-api is a WSGI script
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include apache
    include openstack::install
    include openstack::controller::keystone
    include openstack::controller::users
    PRECOND
  end
  let(:params) do
    {
      placement_pass: 'secret',
      placement_dbpass: 'secret',
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
