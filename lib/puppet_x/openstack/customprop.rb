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
      end
    end

    # parental class with sync check and input valdation for 'domain' parameter
    class DomainParameter < Puppet::Parameter
      defaultto 'default'

      validate do |value|
        raise ArgumentError, _('Domain name or ID must be a String not %{klass} for %{value}') % { klass: value.class, value: value } unless value.is_a?(String)

        next if value.to_s == 'default'
      end
    end

    # ssh key
    class SSHKeyProperty < Puppet::Property
      def retrieve
        provider.provider_show['fingerprint']
      end

      def insync?(is)
        return @should == [:absent] if is.nil? || is.to_s == 'absent'

        key_info = provider.key_info(@should)

        return true if key_info.empty?

        fnc, prn = key_info[:fingerprint].downcase.split(':', 2)
        is == (if fnc == 'md5'
                 prn
               else
                 key_info[:fingerprint]
               end)
      end

      def sync
        provider.destroy
        provider.create
      end
    end

    # parental class with sync check and input valdation for 'security_group' property
    class SecurityGroupProperty < Puppet::Property
      def insync?(is)
        return @should == [:absent] if is.nil? || is.to_s == 'absent'

        group = resource.security_group_instance(@should)
        return true if group && [group[:name], group[:id], group[:group_name]].include?(is)

        false
      end

      validate do |value|
        next if value.to_s == 'absent'

        raise ArgumentError, _('Security group must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      end
    end
  end
end
