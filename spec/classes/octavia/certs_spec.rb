require 'spec_helper'

describe 'openstack::octavia::certs' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          client_ca_pass: 'secret',
          server_ca_pass: 'secret',
        }
      end

      it { is_expected.to compile }
    end
  end
end
