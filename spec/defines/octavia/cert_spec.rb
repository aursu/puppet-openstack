require 'spec_helper'

describe 'openstack::octavia::cert' do
  let(:pre_condition) do
    <<-PRECOND
    openstack::octavia::ca { 'client_ca': pass => 'secret', }
    PRECOND
  end
  let(:title) { 'namevar' }
  let(:params) do
    {
      ca_pass: 'secret',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
