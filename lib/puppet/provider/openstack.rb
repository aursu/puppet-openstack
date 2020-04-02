require 'json'
require 'shellwords'

# Puppet provider for openstack
class Puppet::Provider::Openstack < Puppet::Provider
  # Without initvars commands won't work.
  initvars

  commands openstack: 'openstack'

  if command('openstack')
    confine true: begin
                    openstack('--version')
                  rescue Puppet::ExecutionFailure
                    false
                  else
                    true
                  end
  end

  def self.provider_command
    command(:openstack)
  end

  def self.openstack_command(bin = nil)
    cmd = nil
    cmd = Puppet::Util.which(bin) if bin
    @cmd = if cmd
             cmd
           else
             provider_command
           end
    @cmd
  end

  # Optional defaults file
  def self.openrc_file
    @conf ||= if File.exist?('/root/.openrc')
                '/root/.openrc'
              elsif File.exist?('/etc/keystone/admin-openrc.sh')
                '/etc/keystone/admin-openrc.sh'
              else
                nil
              end
    @conf
  end

  def self.auth_env
    return @env if @env
    return nil unless openrc_file

    @env = nil

    # read file content and remove shell quotes
    data = File.open(@conf).readlines
               .map { |l| Puppet::Util::Execution.execute("echo #{l}") }

    # translate file data into OpenStack env variables hash
    env = data.map { |l| l.sub('export', '').strip }
              .map { |e| e.split('=', 2) }
              .select { |k, _v| k =~ %r{OS_} }

    @env = Hash[env]
  end

  def self.openstack_caller(subcommand, *args)
    # read environment variables for OpenStack authentication
    return nil unless auth_env
    openstack_command unless @cmd

    cmdline = Shellwords.join(args)

    Puppet::Util.withenv(@env) do
      cmdout = Puppet::Util::Execution.execute("#{@cmd} #{subcommand} #{cmdline}", failonfail: false)
      return nil if cmdout.nil?
      return nil if cmdout.empty?
      return cmdout
    end
  end

  def self.get_list_array(entity, *extraargs, long: true)
    openstack_command unless @cmd

    args = ['list', '-f', 'json'] + (long ? ['--long'] : [])
    subcommand = entity
    if @cmd == 'neutron'
      args = ['-f', 'json'] + (long ? ['--long'] : [])
      subcommand = "#{entity}-list"
    end

    args += extraargs

    cmdout = openstack_caller(subcommand, *args)
    return [] if cmdout.nil?

    jout = JSON.parse(cmdout)
    jout.map do |j|
      j.map { |k, v| [k.downcase.tr(' ', '_'), v] }.to_h
    end
  end

  def self.get_list(entity, *extraargs, key: 'name', long: true)
    ret = {}
    jout = get_list_array(entity, *extraargs, long: long)
    jout.each do |p|
      if key.is_a?(Array)
        idx = key.map { |i| p[i] }.join(':')
        ret[idx] = p
      else
        idx = p[key]
        ret[idx] = p.reject { |k, _v| k == key }
      end
    end
    ret
  end

  # Look up the current status.
  def properties
    @property_hash[:ensure] = :absent if @property_hash.empty?
    @property_hash.dup
  end
end
