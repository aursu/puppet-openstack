require 'spec_helper'

describe 'openstack::controller::dashboard' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include apache
    include openstack::install
    PRECOND
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_djangosetting('/etc/openstack-dashboard/local_settings/ALLOWED_HOSTS')
          .with_value("['*']")
      }

      context 'when allowed_hosts provided' do
        let(:params) do
          {
            'allowed_hosts' => ['controller', 'controller.corp.domain.tld'],
          }
        end

        it { is_expected.to compile }

        it {
          is_expected.to contain_djangosetting('/etc/openstack-dashboard/local_settings/ALLOWED_HOSTS')
            .with_value("['controller','controller.corp.domain.tld']")
        }
      end
    end
  end
end
