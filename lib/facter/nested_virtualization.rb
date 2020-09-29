Facter.add(:nested_virtualization) do
  confine { File.exist? '/sys/module/kvm_intel/parameters/nested' }
  setcode do
    File.read('/sys/module/kvm_intel/parameters/nested') =~ %r{Y|1}
  end
end

Facter.add(:nested_virtualization) do
  confine { File.exist? '/sys/module/kvm_amd/parameters/nested' }
  setcode do
    File.read('/sys/module/kvm_amd/parameters/nested') =~ %r{Y|1}
  end
end
