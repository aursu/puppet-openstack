require 'spec_helper'

describe 'openstack::cinder::storage' do
  let(:pre_condition) do
    <<-PRECOND
    include openstack
    include openstack::install
    PRECOND
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

      context 'when device filter set' do
        let(:params) do
          {
            'lvm_devices_filter' => [
              '/dev/sda',
            ],
          }
        end

        it {
          is_expected.to contain_ini_setting('/etc/lvm/lvm.conf/devices/filter')
            .with_value('[ "a|/dev/sda|", "r|.*|" ]')
        }
      end

      context 'when device filter set' do
        let(:params) do
          {
            'physical_volumes' => [
              '/dev/sda4',
              '/dev/sda5',
            ],
          }
        end

        it {
          is_expected.to contain_physical_volume('/dev/sda4')
        }

        it {
          is_expected.to contain_physical_volume('/dev/sda5')
        }

        it {
          is_expected.to contain_volume_group('cinder-volumes')
            .with_physical_volumes(['/dev/sda4', '/dev/sda5'])
        }
      end
    end
  end
end
