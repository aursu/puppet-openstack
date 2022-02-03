require 'spec_helper'

describe 'openstack::service' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    PRECOND
  end
  let(:title) { 'glance' }
  let(:params) do
    {
      service: 'image',
      endpoint: {
        'public'   => 'http://controller:9292',
        'internal' => 'http://controller:9292',
        'admin'    => 'http://controller:9292',
      },
      admin_pass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it {
        is_expected.to contain_openstack_service('glance')
          .with_type('image')
      }

      %w[public internal admin].each do |iface|
        it {
          is_expected.to contain_openstack_endpoint("glance/#{iface}")
            .with_region('RegionOne')
            .with_url('http://controller:9292')
        }
      end

      context 'with missed endpoint' do
        let(:params) do
          super().merge(
            endpoint: {
              'public'   => 'http://controller:9292',
              'internal' => 'http://controller:9292',
            },
          )
        end

        it { is_expected.to raise_error(Puppet::Error, %r{parameter 'endpoint' expects size to be at least 3}) }
      end
    end
  end
end
