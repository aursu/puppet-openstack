require 'spec_helper'

describe 'openstack::cert_subject' do
  it {
    is_expected.to run.with_params(
      'country' => 'US',
      'loc' => 'Portland',
      'org' => 'Kubernetes',
      'unit' => 'CA',
      'state' => 'Oregon',
      'com' => 'Kubernetes',
    ).and_return('/C=US/ST=Oregon/L=Portland/O=Kubernetes/OU=CA/CN=Kubernetes')
  }

  it {
    is_expected.to run.with_params(
      'country' => 'US',
      'loc' => 'Portland',
      'org' => %w[CNCF Kubernetes],
      'unit' => ['CA', 'Intermediate CA'],
      'state' => 'Oregon',
      'com' => 'Kubernetes',
    ).and_return('/C=US/ST=Oregon/L=Portland/O=CNCF/O=Kubernetes/OU=CA/OU=Intermediate CA/CN=Kubernetes')
  }
end
