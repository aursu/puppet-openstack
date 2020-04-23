# Compare the two objects x and y and return an integer according to the outcome.
# The return value is negative if x < y, zero if x == y and positive
# if x > y.
Puppet::Functions.create_function(:'openstack::cyclecmp') do
  dispatch :cyclecmp do
    param 'String', :x
    param 'String', :y
  end

  def cyclecmp(x, y)
    cycles = %w[
      kilo liberty mitaka newton ocata pike queens
      rocky stein train ussuri
    ]

    [x, y].each do |c|
      unless cycles.include?(c)
        raise(Puppet::ParseError, "error: #{c} is not known release (#{cycles})")
      end
    end

    cycles.index(x) - cycles.index(y)
  end
end
