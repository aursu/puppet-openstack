require 'spec_helper'

describe 'openstack::controller::keystoneweb' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include apache
    openstack::repository { 'train': }
    class { 'openstack::controller::keystone': keystone_dbpass => 'secret', admin_pass => 'secret' }
    PRECOND
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
