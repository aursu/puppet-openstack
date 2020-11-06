require 'spec_helper'

describe Puppet::Type.type(:openstack_security_group) do
  let(:resource) do
    described_class.new(
      name: 'lb-mgmt-sec-grp',
    )
  end

  it {
    expect(resource[:project]).to eq(nil)
  }

  it {
    expect(resource[:group_name]).to eq('lb-mgmt-sec-grp')
  }

  it 'check name setup' do
    expect {
      described_class.new(
        name: 'lb-mgmt-sec-grp',
      )
    }.not_to raise_error
  end

  it 'check title setup' do
    expect {
      described_class.new(
        title: 'lb-mgmt-sec-grp',
      )
    }.not_to raise_error
  end

  it 'check project' do
    security_group = described_class.new(:title => 'default/lb-mgmt-sec-grp')
    expect(security_group[:project]).to eq('default')
  end

  it 'check group_name' do
    security_group = described_class.new(:title => 'default/lb-mgmt-sec-grp')
    expect(security_group[:group_name]).to eq('lb-mgmt-sec-grp')
  end
end
