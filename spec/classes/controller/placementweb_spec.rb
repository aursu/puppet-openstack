require 'spec_helper'

describe 'openstack::controller::placementweb' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include apache
    include openstack::install
    include openstack::controller::keystone
    include openstack::controller::users
    include openstack::controller::placement
    PRECOND
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
        is_expected.to contain_concat__fragment('placement-api-wsgi')
          .with_content(%r{WSGIDaemonProcess placement-api group=placement processes=3 threads=1 user=placement})
      }

      it {
        is_expected.to contain_file('apache_wsgi-placement')
          .with_path('/etc/httpd/conf.d/25-wsgi-placement.conf')
          .with_content(%r{Alias /placement-api /usr/bin/placement-api})
      }
    end
  end
end
