require 'spec_helper'

describe Puppet::Type.type(:djangosetting).provider(:ruby) do
  let(:provider) { resource.provider }
  let(:resource) do
    Puppet::Type.type(:djangosetting).new(
      title: Dir.pwd + '/spec/fixtures/files/local_settings/SECRET_KEY',
      ensure: 'present',
      config: Dir.pwd + '/spec/fixtures/files/local_settings',
      value: "'b878c8b69c4eb42f8d63'",
      provider: described_class.name
    )
  end

  context 'check if setting exists?' do
    it {
      expect(provider.exists?).to eq true
    }

    it {
      expect(provider.line).to eq "SECRET_KEY='b878c8b69c4eb42f8d63'"
    }
  end

  context 'check if setting exists when ensure is absent' do
    let(:resource) do
      Puppet::Type.type(:djangosetting).new(
        title: Dir.pwd + '/spec/fixtures/files/local_settings/OPENSTACK_HOST',
        ensure: 'absent',
        config: Dir.pwd + '/spec/fixtures/files/local_settings',
        provider: described_class.name
      )
    end

    it {
      expect(provider.exists?).to eq true
    }

    it {
      expect(provider.line).to match(%r{^OPENSTACK_HOST=})
    }
  end

  context 'check if value replaced' do
    let(:resource) do
      Puppet::Type.type(:djangosetting).new(
        title: Dir.pwd + '/spec/fixtures/files/local_settings/LOCAL_PATH',
        ensure: 'present',
        config: Dir.pwd + '/spec/fixtures/files/local_settings',
        value: "'/var/tmp'",
        provider: described_class.name
      )
    end

    it 'is exists but with different value (exists? returns nil)' do
      expect(provider.exists?).to eq nil
    end

    it {
      expect(provider.lines).to include("LOCAL_PATH='/var/tmp'")
    }
  end

  context 'check if value added' do
    let(:resource) do
      Puppet::Type.type(:djangosetting).new(
        title: Dir.pwd + '/spec/fixtures/files/local_settings/SESSION_ENGINE',
        ensure: 'present',
        config: Dir.pwd + '/spec/fixtures/files/local_settings',
        value: "'django.contrib.sessions.backends.signed_cookies'",
        provider: described_class.name
      )
    end

    it {
      expect(provider.exists?).to eq false
    }

    it {
      expect(provider.lines).to include("SESSION_ENGINE='django.contrib.sessions.backends.signed_cookies'")
    }
  end
end
