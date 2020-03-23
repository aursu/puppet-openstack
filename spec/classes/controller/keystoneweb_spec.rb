require 'spec_helper'

describe 'openstack::controller::keystoneweb' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include apache
    include openstack::install
    include openstack::controller::keystone
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
        is_expected.to contain_concat__fragment('keystone-public-apache-header')
          .with_content(%r{^\s+LimitRequestBody 114688$})
      }

      it {
        is_expected.not_to contain_concat__fragment('keystone-public-docroot')
      }

      it {
        is_expected.to contain_concat__fragment('keystone-public-logging')
          .with_content(%r{^\s+ErrorLogFormat "%\{cu\}t %M"$})
      }
    end
  end
end
