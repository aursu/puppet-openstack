Facter.add(:virtualization_support) do
  setcode do
    cpu_flags = File.readlines('/proc/cpuinfo').grep(%r{flags})
    virtualization_support = nil
    if cpu_flags.grep(%r{vmx}).size >= 1
      virtualization_support = 'vmx'
    elsif cpu_flags.grep(%r{svm}).size >= 1
      virtualization_support = 'svm'
    end
  end
end
