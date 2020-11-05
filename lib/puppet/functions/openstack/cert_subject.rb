
Puppet::Functions.create_function(:'openstack::cert_subject') do
  dispatch :cert_subject do
    param 'Openstack::CertName', :subj
  end

  def attrs
    %w[country state loc org unit com email_address]
  end

  def labels
    {
      'country'       => 'C',
      'state'         => 'ST',
      'loc'           => 'L',
      'org'           => 'O',
      'unit'          => 'OU',
      'com'           => 'CN',
      'email_address' => 'emailAddress',
    }
  end

  def field_str(attr, field)
    if field.is_a?(Array)
      field.map { |v| [labels[attr], v.to_s].join('=') }.join('/')
    else
      [labels[attr], field.to_s].join('=')
    end
  end

  def cert_subject(subj)
    subj = Hash[subj.map { |l, v| [l.to_s, v] }]

    subj_str = attrs.select { |a| subj[a] }
                    .map { |a| field_str(a, subj[a]) }
                    .join('/')
    "/#{subj_str}"
  end
end
