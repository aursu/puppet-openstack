require 'shellwords'

Puppet::Type.type(:ceph_auth).provide(:ceph) do
  desc 'Manage Ceph user.'

  commands ceph: 'ceph'

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

    cmdout = Puppet::Util::Execution.execute(cmd)
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

  def self.ceph_get_array(subcomm, *args)
    get_args = ['-f', 'json', 'get']
    args = get_args + args

    cmdout = ceph_caller(subcomm, *args)
    return [] unless cmdout

    JSON.parse(cmdout)
  end

  def self.provider_subcommand
    'auth'
  end

  def self.provider_get(name)
    # first element is a desired  object 
    # empty hash if not exist
    ceph_get_array(provider_subcommand, name).first || {}
  end

  def self.provider_create(*args)
    ceph_caller(provider_subcommand, 'add', *args)
  end

  def self.provider_delete(*args)
    ceph_caller(provider_subcommand, 'del', *args)
  end

  def self.provider_set(*args)
    ceph_caller(provider_subcommand, 'caps', *args)
  end

  def self.get_or_create(*args)
    ceph_caller(provider_subcommand, 'get-or-create', *args)
  end

  def user_info
    name = @resource[:name]

    @data ||= self.class.provider_get(name)
  end

  def auth_args
    #  ceph auth get-or-create client.cinder-backup mon 'profile rbd' osd 'profile rbd pool=backups' mgr 'profile rbd pool=backups'
    name    = @resource[:name]
    cap_mon = @resource[:cap_mon]
    cap_osd = @resource[:cap_osd]
    cap_mgr = @resource[:cap_mgr]
    cap_mds = @resource[:cap_mds]

    args = [name]
    args += ['mon', cap_mon] if cap_mon
    args += ['osd', cap_osd] if cap_osd
    args += ['mgr', cap_mgr] if cap_mgr
    args += ['mds', cap_mds] if cap_mds
  end

  def create
    self.class.provider_create(*auth_args)
  end

  def destroy
    name = @resource[:name]

    self.class.provider_delete(name)
  end

  # [
  #    {
  #       "entity":"client.username",
  #       "key":"********",
  #       "caps":{
  #         "mgr":"profile rbd pool=poolname",
  #         "mon":"profile rbd",
  #         "osd":"profile rbd pool=poolname"
  #       }
  #     }
  # ]
  def exists?
    name = @resource[:name]
    user_info['entity'] == name
  end

  def cap_mon
    name = @resource[:name]
    user_info['caps']['mon']
  end

  def cap_mon=(caps)
    self.class.provider_set(*auth_args)
  end

  def cap_osd
    name = @resource[:name]
    user_info['caps']['osd']
  end

  def cap_osd=(caps)
    self.class.provider_set(*auth_args)
  end

  def cap_mgr
    name = @resource[:name]
    user_info['caps']['mgr']
  end

  def cap_mgr=(caps)
    self.class.provider_set(*auth_args)
  end

  def cap_mds
    name = @resource[:name]
    user_info['caps']['mds']
  end

  def cap_mds=(caps)
    self.class.provider_set(*auth_args)
  end

  def get_or_create
    name = @resource[:name]
    self.class.get_or_create(name)
  end
end