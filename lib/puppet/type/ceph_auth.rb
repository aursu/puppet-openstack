Puppet::Type.newtype(:ceph_auth) do

  @doc = <<-PUPPET
    @summary
      Ceph Client users, and their authentication and authorization with the Ceph
      Storage Cluster. Users are either individuals or system actors such as
      applications, which use Ceph clients to interact with the Ceph Storage Cluster
      daemons

      https://docs.ceph.com/en/latest/rados/operations/user-management/
    PUPPET

  ensurable

  newparam(:name) do
    desc 'Ceph client user name'
  end

  newparam(:cluster) do
    desc 'Ceph cluster name'

    defaultto 'ceph'
  end

  newproperty(:cap_mon) do
    desc 'Monitor capabilities.'
  end

  newproperty(:cap_osd) do
    desc 'OSD capabilities.'
  end

  newproperty(:cap_mgr) do
    desc 'Manager (ceph-mgr) capabilities.'
  end

  newproperty(:cap_mds) do
    desc 'Metadata server capabilities.'
  end

  # https://docs.ceph.com/en/latest/rados/operations/user-management/#create-a-keyring
  #  eg /etc/ceph/ceph.client.admin.keyring
  def generate
    cluster = self[:cluster]
    user    = self[:name]
    should  = self.should(:ensure) || :present

    path    = "/etc/ceph/#{cluster}.#{user}.keyring"
    return [] if catalog.resource(:file, path)

    [Puppet::Type.type(:file).new(name: path, ensure: should, content: provider.get_or_create)]
  end
end