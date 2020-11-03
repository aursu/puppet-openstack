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

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
