Facter.add(:virtualization_support) do
  setcode do
    cpu_flags = File.readlines('/proc/cpuinfo').grep(%r{flags})

    virtualization_support = if cpu_flags.grep(%r{vmx}).size >= 1
                               'vmx'
                             elsif cpu_flags.grep(%r{svm}).size >= 1
                               'svm'
                             else
                               nil
                             end
    virtualization_support
  end
end
