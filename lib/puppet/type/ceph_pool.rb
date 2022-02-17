Puppet::Type.newtype(:ceph_pool) do

  @doc = <<-PUPPET
    @summary
      Pools are logical partitions for storing objects.
      To organize data into pools, you can list, create, and remove pools.
    PUPPET

  ensurable

  newparam(:name) do
    desc 'The name of the pool. It must be unique.'
  end

  newproperty(:rbd_init) do
    desc 'Initialize pool for use by RBD.'

    newvalues(:true, :false)
    defaultto :true
  end
end