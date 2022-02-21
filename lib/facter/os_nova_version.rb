require 'puppet/util/execution'

Facter.add(:os_nova_version) do
  setcode do
    maj = 0
    if Puppet::Util.which('nova-manage')
      nova_version = Puppet::Util::Execution.execute('nova-manage --version', combine: true)
      m = %r{^(\d+)}.match(nova_version)
      maj = m[0].to_i
    end
    maj
  end
end
