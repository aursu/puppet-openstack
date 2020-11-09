require 'shellwords'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'openstack'))

Puppet::Type.type(:openstack_keypair).provide(:openstack, parent: Puppet::Provider::Openstack) do
  desc 'Manage keypairs for OpenStack.'

  commands openstack: 'openstack'
  commands ssh_keygen: 'ssh-keygen'

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def self.provider_subcommand
    'keypair'
  end

  def self.provider_create(*args)
    openstack_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    openstack_caller(provider_subcommand, 'delete', *args)
  end

  def self.provider_show(*args)
    openstack_caller(provider_subcommand, 'show', *args)
  end

  def self.ssh_keygen_command(bin = nil)
    cmd = nil
    cmd = Puppet::Util.which(bin) if bin
    @keygen_cmd = if cmd
             cmd
           else
             command(:ssh_keygen)
           end
    @keygen_cmd
  end

  def self.ssh_keygen_caller(*args)
    ssh_keygen_command unless @keygen_cmd
    cmdline = Shellwords.join(args)

    cmd = [@keygen_cmd, cmdline].compact.join(' ')
    cmdout = Puppet::Util::Execution.execute(cmd)

    return nil if cmdout.nil?
    return nil if cmdout.empty?
    return cmdout
  rescue Puppet::ExecutionFailure => detail
    Puppet.debug "Execution of #{@keygen_cmd} command failed: #{detail}"
    false
  end

  def key_info(path)
    path = [path].flatten.shift

    args = ['-l', '-E', 'md5', '-f', path]
    cmdout = self.class.ssh_keygen_caller(*args)

    return {} unless cmdout

    size, fprint, name_type = cmdout.split(' ', 3)
    name_type = name_type.split(' ')

    {
      size: size,
      fingerprint: fprint,
      type: name_type.pop,
      name: name_type.join(' '),
    }
  end

  def provider_show
    return @desc if @desc

    name = @resource[:name]

    args = ['-f', 'json', name]
    auth_args

    cmdout = self.class.provider_show(*args)
    return {} unless cmdout

    @desc = JSON.parse(cmdout).map { |k, v| [k.downcase.tr(' ', '_'), v] }.to_h
  end

  # usage: openstack keypair create
  #  [--public-key <file> | --private-key <file>]
  #  <name>
  def create
    name             = @resource[:name]
    public_key       = @resource.value(:public_key)
    private_key      = @resource.value(:private_key)

    args = []
    if public_key && File.exist?(public_key)
      args += ['--public-key', public_key]
    elsif private_key
      args += ['--private-key', private_key]
    else
      warning _('Can not use either --public-key (file does not exist) or --private-key (not specified)')
      return
    end
    args << name

    auth_args

    self.class.provider_create(*args)
  end

  def destroy
    name = @resource[:name]
    private_key = @resource.value(:private_key)

    # --private-key will be generated only if file absent
    File.unlink(private_key) if File.exist?(private_key)

    auth_args

    self.class.provider_delete(name)
  end

  def exists?
    provider_show.any?
  end
end
