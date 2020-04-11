require 'puppet/property'

module PuppetX::OpenStack
  class ProjectProperty < Puppet::Property
    def insync?(is)
      return @should == [:absent] if is.nil?

      proj = resource.project_instance(@should)
      return true if proj && [proj[:name], proj[:id]].include?(is)

      false
    end

    validate do |value|
      next if value.to_s == 'absent'

      raise ArgumentError, _('Project name or ID must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

      proj = resource.project_instance(value) || resource.project_resource(value)
      raise ArgumentError, _("Project #{value} must be defined in catalog or exist in OpenStack environment") unless proj
    end
  end

  class NetworkProperty < Puppet::Property
    def insync?(is)
      return @should == [:absent] if is.nil?

      net = resource.network_instance(@should)
      return true if net && [net[:name], net[:id]].include?(is)

      false
    end

    validate do |value|
      next if value.to_s == 'absent'

      raise ArgumentError, _('Network must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

      net = resource.network_instance(value) || resource.network_resource(value)
      raise ArgumentError, _("Network #{value} must be defined in catalog or exist in OpenStack environment") unless net
    end
  end

  class SubnetProperty < Puppet::Property
    def insync?(is)
      return @should == [:absent] if is.nil?

      sub = resource.subnet_instance(@should)
      return true if sub && [sub[:name], sub[:id]].include?(is)

      false
    end

    validate do |value|
      next if value.to_s == 'absent'

      raise ArgumentError, _('Network must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

      sub = resource.subnet_instance(value) || resource.subnet_resource(value)
      raise ArgumentError, _("Subnet #{value} must be defined in catalog or exist in OpenStack environment") unless sub
    end
  end
end
