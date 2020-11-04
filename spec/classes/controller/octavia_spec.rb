require 'spec_helper'

describe 'openstack::controller::octavia' do
  on_supported_os.each do |os, os_facts|
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
        octavia_pass: 'secret',
        octavia_dbpass: 'secret',
      }
    end
    before(:each) do
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:directory?).with('/var/lib/compose/octavia/.').and_return(true)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/var/lib/compose/octavia/./Dockerfile').and_return(true)
    end

    context "on #{os}" do
      let(:facts) do
        os_facts.merge(
          hostname: 'controller',
          stype: 'openstack',
        )
      end

      it { is_expected.to compile }
    end
  end
end
