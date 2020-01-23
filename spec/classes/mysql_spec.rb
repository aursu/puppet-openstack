require 'spec_helper'

describe 'openstack::mysql' do
  let(:pre_condition) { 'include openstack' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
