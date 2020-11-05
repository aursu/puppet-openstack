require 'spec_helper'

describe 'openstack::octavia::amphora' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    PRECOND
  end
  let(:params) do
    {
      octavia_pass: 'secret',
    }
  end

  # before(:each) do
  #   allow(File).to receive(:directory?).and_call_original
  #   allow(File).to receive(:directory?).with('/var/lib/compose/octavia/.').and_return(true)
  #   allow(File).to receive(:exist?).and_call_original
  #   allow(File).to receive(:exist?).with('/var/lib/compose/octavia/./Dockerfile').and_return(true)
  # end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
