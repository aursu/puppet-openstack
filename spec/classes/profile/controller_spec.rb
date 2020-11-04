require 'spec_helper'

describe 'openstack::profile::controller' do
  let(:pre_condition) { 'include apache' }
  before(:each) do
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?).with('/var/lib/compose/octavia/.').and_return(true)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('/var/lib/compose/octavia/./Dockerfile').and_return(true)
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
    end
  end
end
