$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customcomm'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_keypair) do
  extend CustomComm
  include CustomType

  @doc = <<-PUPPET
    @summary
      Create public key of an OpenSSH key pair to be used for access to created
      servers. You can also create a private key for access to a created server by not
      passing any argument to the keypair create command.
    PUPPET

  ensurable do
    newvalue(:absent) do
      provider.destroy
    end

    newvalue(:present) do
      provider.create
    end

    defaultto :present

    def retrieve
      return :present if provider.exists?
      :absent
    end
  end

  newparam(:name, namevar: true) do
    desc 'Keypair name'
  end

  newproperty(:public_key, parent: PuppetX::OpenStack::SSHKeyProperty) do
    desc 'Filename for public key to add. If not used, creates a private key.'
  end

  newproperty(:private_key, parent: PuppetX::OpenStack::SSHKeyProperty) do
    desc 'Filename for private key to save. If not used, print private key in console.'
  end

  validate do
    if @parameters[:public_key] && @parameters[:private_key]
      raise Puppet::Error, _('error: argument --private-key: not allowed with argument --public-key')
    end
  end

  def stat(path)
    Puppet::FileSystem.stat(path)
  rescue Errno::ENOENT
    nil
  rescue Errno::ENOTDIR
    nil
  rescue Errno::EACCES
    warning _('Could not stat; permission denied')
    nil
  rescue Errno::EINVAL
    warning _('Could not stat; invalid pathname')
    nil
  end
end
