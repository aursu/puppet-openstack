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

    auth = if @auth_args
             Shellwords.join(@auth_args)
           else
             nil
           end

    cmdline = Shellwords.join(args)

    cmd = [@cmd, auth, subcommand, cmdline].compact.join(' ')

    Puppet::Util.withenv(@env) do
      cmdout = Puppet::Util::Execution.execute(cmd)
      return nil if cmdout.nil?
      return nil if cmdout.empty?
      return cmdout
    end
  rescue Puppet::ExecutionFailure => detail
    Puppet.debug "Execution of #{@cmd} command failed: #{detail}"
    false
  end

  def self.get_list_array(entity, long = true, *moreargs)
    openstack_command unless @cmd

    args = ['list', '-f', 'json'] + (long ? ['--long'] : [])
    subcommand = entity
    if @cmd == 'neutron'
      args = ['-f', 'json'] + (long ? ['--long'] : [])
      subcommand = "#{entity}-list"
    end

    args += moreargs

    cmdout = openstack_caller(subcommand, *args)
    return [] if cmdout.nil?

    jout = JSON.parse(cmdout)
    jout.map do |j|
      j.map { |k, v| [k.downcase.tr(' ', '_'), v] }.to_h
    end
  end

  def self.get_list(entity, key = 'name', long = true, *args)
    ret = {}
    jout = get_list_array(entity, long, *args)
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

  def self.auth_args(*args)
    @auth_args = nil
    @auth_args = args unless args.empty?
  end

  # Look up the current status.
  def properties
    @property_hash[:ensure] = :absent if @property_hash.empty?
    @property_hash.dup
  end

  def empty_or_absent(value)
    return true if value.nil?
    return true if value.is_a?(String) && value.empty?
    return true if value == :absent
    false
  end

  def auth_args
    auth_project_domain_name = @resource.value(:auth_project_domain_name)
    auth_user_domain_name    = @resource.value(:auth_user_domain_name)
    auth_project_name        = @resource.value(:auth_project_name)
    auth_username            = @resource.value(:auth_username)
    auth_password            = @resource.value(:auth_password)
    auth_url                 = @resource.value(:auth_url)
    identity_api_version     = @resource.value(:identity_api_version)
    image_api_version        = @resource.value(:image_api_version)

    args = []
    args += ['--os-project-domain-name', auth_project_domain_name] unless empty_or_absent(auth_project_domain_name)
    args += ['--os-user-domain-name', auth_user_domain_name] unless empty_or_absent(auth_user_domain_name)
    args += ['--os-project-name', auth_project_name] unless empty_or_absent(auth_project_name)
    args += ['--os-username', auth_username] unless empty_or_absent(auth_username)
    args += ['--os-password', auth_password] unless empty_or_absent(auth_password)
    args += ['--os-auth-url', auth_url] unless empty_or_absent(auth_url)
    args += ['--os-identity-api-version', identity_api_version] unless empty_or_absent(identity_api_version)
    args += ['--os-image-api-version', image_api_version] unless empty_or_absent(image_api_version)

    self.class.auth_args(*args)
  end
end
