require 'spec_helper'

describe Puppet::Type.type(:djangosetting).provider(:ruby) do
  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:provider) { resource.provider }

  context 'check if setting exists?' do
    let(:resource) do
      Puppet::Type.type(:djangosetting).new(
        title: Dir.pwd + '/spec/fixtures/files/local_settings/SECRET_KEY',
        ensure: 'present',
        config: Dir.pwd + '/spec/fixtures/files/local_settings',
        value: "'b878c8b69c4eb42f8d63'",
        provider: described_class.name,
      )
    end

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
        provider: described_class.name,
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
        provider: described_class.name,
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
        provider: described_class.name,
      )
    end

    it {
      expect(provider.exists?).to eq false
    }

    it {
      expect(provider.lines).to include("SESSION_ENGINE='django.contrib.sessions.backends.signed_cookies'")
    }
  end

  context 'check auto require' do
    let(:session_engine) do
      Puppet::Type.type(:djangosetting).new(
        title: Dir.pwd + '/spec/fixtures/files/local_settings/SESSION_ENGINE',
        value: "'django.contrib.sessions.backends.signed_cookies'",
      )
    end

    it 'CACHES autorequire SESSION_ENGINE' do
      caches = Puppet::Type.type(:djangosetting).new(
        title:         Dir.pwd + '/spec/fixtures/files/local_settings/CACHES',
        value:        <<-PYCODE,
          'default': {
            'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
            'LOCATION': 'controller:11211'
          }
        PYCODE
        order_after: 'SESSION_ENGINE',
        catalog:       catalog,
      )

      catalog.add_resource session_engine
      catalog.add_resource caches
      dependencies = caches.autorequire(catalog)

      expect(dependencies.map(&:to_s)).to eq([Puppet::Relationship.new(session_engine, caches).to_s])
    end
  end
end
