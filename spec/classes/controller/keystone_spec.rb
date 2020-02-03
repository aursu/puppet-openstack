require 'spec_helper'

describe 'openstack::controller::keystone' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    openstack::repository { 'train':
    }
    PRECOND
  end
  let(:params) do
    {
      keystone_dbpass: 'secret',
      admin_pass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_exec('keystone-manage-bootstrap')
          .with_command(%r{--bootstrap-admin-url http://controller:5000/v3/})
      }

      context 'when release cycle is before the Queens release' do
        let(:pre_condition) do
          <<-PRECOND
          include openstack
          openstack::repository { 'pike':
          }
          PRECOND
        end
        let(:params) do
          super().merge(
            'cycle' => 'pike',
          )
        end

        it {
          is_expected.to contain_exec('keystone-manage-bootstrap')
            .with_command(%r{--bootstrap-admin-url http://controller:35357/v3/})
        }
      end
    end
  end
end
