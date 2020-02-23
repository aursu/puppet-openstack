require 'spec_helper'

describe 'openstack::djangoconfig' do
  let(:title) { '/etc/openstack-dashboard/local_settings' }
  let(:params) do
    {}
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          content: {
            'OPENSTACK_HOST' => "'controller'",
          },
        }
      end

      it { is_expected.to compile }

      it {
        is_expected.to contain_djangosetting('/etc/openstack-dashboard/local_settings/OPENSTACK_HOST')
          .with(
            ensure: :present,
            config: '/etc/openstack-dashboard/local_settings',
            value: "'controller'",
          )
      }
    end
  end
end
