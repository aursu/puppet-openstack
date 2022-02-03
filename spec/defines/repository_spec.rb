require 'spec_helper'

describe 'openstack::repository' do
  let(:title) { 'train' }
  let(:params) do
    {}
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      to_remove = case os
                  when %r{centos-7}
                    %w[queens rocky stein]
                  when %r{centos-8}
                    %w[ussuri victoria]
                  end

      to_remove.each do |cycle|
        it {
          is_expected.to contain_file("/etc/yum.repos.d/CentOS-OpenStack-#{cycle}.repo")
            .with_ensure('absent')
        }

        it {
          is_expected.to contain_package("centos-release-openstack-#{cycle}")
            .with_ensure('absent')
            .that_notifies('Exec[yum-reload-c01e6ce]')
        }
      end

      it {
        is_expected.to contain_package('centos-release-openstack-train')
          .with_ensure('present')
          .that_notifies('Exec[yum-reload-c01e6ce]')
      }
    end
  end
end
