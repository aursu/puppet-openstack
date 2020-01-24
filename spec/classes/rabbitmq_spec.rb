require 'spec_helper'

describe 'openstack::rabbitmq' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include rabbitmq
    PRECOND
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          rabbit_pass: 'secret',
        }
      end

      it { is_expected.to compile }
    end
  end
end
