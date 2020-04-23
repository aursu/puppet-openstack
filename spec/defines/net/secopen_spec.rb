require 'spec_helper'

describe 'openstack::net::secopen' do
  let(:pre_condition) do
    <<-PRECOND
    openstack_project { 'cloud': }
    PRECOND
  end
  let(:title) { 'cloud' }
  let(:params) do
    {}
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
