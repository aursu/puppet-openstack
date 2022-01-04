Facter.add(:nested_virtualization) do
  confine { File.exist? '/sys/module/kvm_intel/parameters/nested' }
  setcode do
    if File.read('/sys/module/kvm_intel/parameters/nested').match?(%r{Y|1})
      true
    else
      false
    end
  end
end

Facter.add(:nested_virtualization) do
  confine { File.exist? '/sys/module/kvm_amd/parameters/nested' }
  setcode do
    if File.read('/sys/module/kvm_amd/parameters/nested').match?(%r{Y|1})
      true
    else
      false
    end
  end
end
