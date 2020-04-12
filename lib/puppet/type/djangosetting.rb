require 'English'

# https://docs.puppet.com/guides/custom_types.html
Puppet::Type.newtype(:djangosetting) do
  @doc = 'Manage django settings file'
  # This property uses three methods on the provider: "create", "destroy",
  # and "exists?". The last method, somewhat obviously, is a boolean to
  # determine if the resource current exists. If a resource's ensure property
  # is out of sync, then no other properties will be checked or modified.
  ensurable do
    defaultvalues
    defaultto :present
  end

  def self.title_patterns
    [
      [
        %r{^(.*)\/([^\/]*)$},
        [
          [:config],
          [:name],
        ],
      ],
    ]
  end

  newparam(:name) do
    isnamevar
    validate do |value|
      raise ArgumentError, 'name should be valid python identifier' unless value =~ %r{^[a-zA-Z_][a-zA-Z0-9_]*}
    end
  end

  newparam(:config) do
    desc 'The django setting file.'
    isnamevar
    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise Puppet::Error, "File paths must be fully qualified, not '#{value}'"
      end
    end
  end

  newparam(:order_after) do
    desc 'An optional variable name used to specify the variable after which we will add any new.'
    validate do |value|
      raise ArgumentError, 'after should be valid python identifier' unless value =~ %r{^[a-zA-Z_][a-zA-Z0-9_]*}
    end

    newvalues(%r{[a-zA-Z_][a-zA-Z0-9_]*})
  end

  newparam(:path) do
    desc "The search path used for python comman search. Paths
    can be specified as an array or as a '#{File::PATH_SEPARATOR}' separated list."
    def value=(*values)
      @value = values.flatten.map { |val|
        val.split(File::PATH_SEPARATOR)
      }.flatten
    end
    defaultto '/bin:/usr/bin:/usr/local/bin'
  end

  newparam(:timeout) do
    munge do |value|
      value = value.shift if value.is_a?(Array)
      begin
        value = Float(value)
      rescue ArgumentError
        raise ArgumentError, 'The timeout must be a number.', $ERROR_INFO.backtrace
      end
      [value, 0.0].max
    end
    defaultto 300
  end

  newparam(:value) do
    desc 'Value of the variable'
  end

  autorequire(:djangosetting) do
    req = []
    req << File.join(self[:config], self[:order_after]) if self[:order_after]
    req
  end

  validate do
    unless self[:value]
      unless self[:ensure].to_s == 'absent'
        raise Puppet::Error, 'value is a required attribute'
      end
    end

    raise Puppet::Error, 'config is a required attribute' unless self[:config]
  end
end
