require 'puppet/property'

#
module PuppetX
  module OpenStack
    # parental class with sync check and input valdation for 'project' property
    class ProjectProperty < Puppet::Property
      def insync?(is)
        return @should == [:absent] if is.nil? || is.to_s == 'absent'

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

    # parental class with sync check and input valdation for 'network' property
    class NetworkProperty < Puppet::Property
      def insync?(is)
        return @should == [:absent] if is.nil? || is.to_s == 'absent'

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

    # parental class with sync check and input valdation for 'subnet' property
    class SubnetProperty < Puppet::Property
      def insync?(is)
        return @should == [:absent] if is.nil? || is.to_s == 'absent'

        subnet = resource.subnet_instance(@should)
        return true if subnet && [subnet[:name], subnet[:id]].include?(is)

        false
      end

      validate do |value|
        next if value.to_s == 'absent'

        raise ArgumentError, _('Network must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

        subnet = resource.subnet_instance(value) || resource.subnet_resource(value)
        raise ArgumentError, _("Subnet #{value} must be defined in catalog or exist in OpenStack environment") unless subnet
      end
    end

    # parental class with sync check and input valdation for 'role' property
    class RoleProperty < Puppet::Property
      def insync?(is)
        return @should == [:absent] if is.nil? || is.to_s == 'absent'

        role = resource.role_instance(@should)
        return true if role && [role[:name], role[:id]].include?(is)

        false
      end

      validate do |value|
        next if value.to_s == 'absent'

        raise ArgumentError, _('Network must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

        role = resource.role_instance(value) || resource.role_resource(value)
        raise ArgumentError, _("Subnet #{value} must be defined in catalog or exist in OpenStack environment") unless role
      end
    end

    # parental class with sync check and input valdation for 'user' property
    class UserProperty < Puppet::Property
      def insync?(is)
        return @should == [:absent] if is.nil? || is.to_s == 'absent'

        user = resource.user_instance(@should)
        return true if user && [user[:name], user[:id]].include?(is)

        false
      end

      validate do |value|
        next if value.to_s == 'absent'

        raise ArgumentError, _('User must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

        user = resource.user_instance(value) || resource.user_resource(value)
        raise ArgumentError, _("User #{value} must be defined in catalog or exist in OpenStack environment") unless user
      end
    end

    # parental class with sync check and input valdation for 'domain' property
    class DomainProperty < Puppet::Property
      def insync?(is)
        return @should == [:absent] if is.nil? || is.to_s == 'absent'

        domain = resource.domain_instance(@should)
        return true if domain && [domain[:name], domain[:id]].include?(is)

        false
      end

      validate do |value|
        next if value.to_s == 'absent'

        raise ArgumentError, _('Domain must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

        domain = resource.domain_instance(value) || resource.domain_resource(value)
        raise ArgumentError, _("Domain #{value} must be defined in catalog or exist in OpenStack environment") unless domain
      end
    end

    # parental class with sync check and input valdation for 'domain' parameter
    class DomainParameter < Puppet::Parameter
      defaultto 'default'

      validate do |value|
        raise ArgumentError, _('Domain name or ID must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

        next if value.to_s == 'default'

        domain = resource.domain_instance(value) || resource.domain_resource(value)
        raise ArgumentError, _("Domain #{value} must be defined in catalog or exist in OpenStack environment") unless domain
      end
    end
  end
end
