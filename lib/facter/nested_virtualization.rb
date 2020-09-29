Facter.add(:nested_virtualization) do
  setcode do
    # Try intel first
    nested = false
    begin
      return true if File.read('/sys/module/kvm_intel/parameters/nested') =~ %r{Y|1}
    rescue SystemCallError
      nested = false
    end

    begin
      return true if File.read('/sys/module/kvm_amd/parameters/nested') =~ %r{Y|1}
    rescue SystemCallError
      nested = false
    end

    nested
  end
end
