require 'shellwords'
require 'json'

Puppet::Type.type(:ceph_pool).provide(:ceph) do
  desc 'Manage Ceph pools'

  commands ceph: 'ceph'
  commands rbd: 'rbd'

  if command(:ceph)
    confine true: begin
                    ceph('--version')
                  rescue Puppet::ExecutionFailure
                    false
                  else
                    true
                  end
  end

  def self.util_caller(comm, subcomm, *args)
    cmdline = Shellwords.join(args)
    cmd = [comm, subcomm, cmdline].compact.join(' ')

    cmdout = Puppet::Util::Execution.execute(cmd, combine: false)
    return nil if cmdout.nil?
    return nil if cmdout.empty?
    return cmdout
  rescue Puppet::ExecutionFailure => detail
    Puppet.debug "Execution of #{comm} command failed: #{detail}"
    false
  end 

  def self.ceph_caller(subcomm, *args)
    util_caller(command(:ceph), subcomm, *args)
  end

  def self.rbd_caller(subcomm, *args)
    util_caller(command(:rbd), subcomm, *args)
  end

  def self.ceph_get(subcomm, *args)
    get_args = ['-f', 'json', 'get']
    args = get_args + args

    cmdout = ceph_caller(subcomm, *args)
    return {} unless cmdout

    JSON.parse(cmdout)
  end

  def pool_application_get(pool)
    self.class.ceph_get('osd pool application', pool)
  end

  def self.provider_subcommand
    'osd pool'
  end

  def self.provider_get(pool, parameter = 'all')
    ceph_get(provider_subcommand, pool, parameter)
  end

  def self.provider_create(*args)
    ceph_caller(provider_subcommand, 'create', *args)
  end

  def self.provider_delete(*args)
    ceph_caller(provider_subcommand, 'delete', *args)
  end

  def self.provider_set(*args)
    ceph_caller(provider_subcommand, 'set', *args)
  end

  def pool_info
    name = @resource[:name]

    @data ||= self.class.provider_get(name)
  end

  def create
    name = @resource[:name]

    args = []
    args << name

    self.class.provider_create(*args)
  end

  def destroy
    name = @resource[:name]

    self.class.provider_delete(name)
  end

  def exists?
    name = @resource[:name]
    pool_info['pool'] == name
  end

  def rbd_init
    name = @resource[:name]
    app_info = pool_application_get(name)

    # RBD uses the application name `rbd`
    init_status = !app_info['rbd'].nil?

    # either :true or :false
    init_status.to_s.to_sym
  end

  def rbd_init=(status)
    name = @resource[:name]

    if status == :true
      # Pools that are intended for use with RBD should be initialized using the `rbd` tool
      self.class.rbd_caller('pool init', name)
    else
      self.class.ceph_caller('osd pool application disable', name, 'rbd', '--yes-i-really-mean-it')
    end
  end
end