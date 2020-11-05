require 'shellwords'

Puppet::Functions.create_function(:'openstack::shell_escape') do
  dispatch :shell_escape do
    param 'String', :param
  end

  def shell_escape(param)
    Shellwords.shellescape(param)
  end
end
