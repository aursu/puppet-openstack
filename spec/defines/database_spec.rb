require 'spec_helper'

describe 'openstack::database' do
  let(:title) { 'keystone' }
  let(:params) do
    {
      dbuser: 'keystone',
      dbpass: 'secret',
      database_tag: 'openstack',
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
