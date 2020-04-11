#
module CustomType
  class << self
    def included(base)
      base.extend ClassMethods
    end
  end

  def project_instance(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id

    instances = Puppet::Type.type(:openstack_project).instances
                            .select { |resource| resource[:name] == lookup_id || resource[:id] == lookup_id }
    return nil if instances.empty?
    # no support for multiple OpenStack domains
    instances.first
  end

  def project_resource(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id
    catalog.resources.find { |r| r.is_a?(Puppet::Type.type(:openstack_project)) && [r[:name], r[:id]].include?(lookup_id) }
  end

  def network_instance(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id

    instances = Puppet::Type.type(:openstack_network).instances
                            .select { |resource| resource[:name] == lookup_id || resource[:id] == lookup_id }

    return nil if instances.empty?
    instances.first
  end

  def network_resource(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id
    catalog.resources.find { |r| r.is_a?(Puppet::Type.type(:openstack_network)) && [r[:name], r[:id]].include?(lookup_id) }
  end

  def subnet_instance(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id

    instances = Puppet::Type.type(:openstack_subnet).instances
                            .select { |resource| resource[:name] == lookup_id || resource[:id] == lookup_id }
    return nil if instances.empty?

    instances.first
  end

  def subnet_resource(lookup_id)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id
    catalog.resources.find { |r| r.is_a?(Puppet::Type.type(:openstack_subnet)) && [r[:name], r[:id]].include?(lookup_id) }
  end

  # class methods for base class
  module ClassMethods
    def instances
      return @instances if @instances
      # Put the default provider first, then the rest of the suitable providers.
      provider_instances = {}

      # introduce class variable - we must call read current state once per run
      type_instances = providers_by_source.map do |provider|
        provider.instances.map do |instance|
          # We always want to use the "first" provider instance we find, unless the resource
          # is already managed and has a different provider set
          if other = provider_instances[instance.name] # rubocop:disable Lint/AssignmentInCondition
            Puppet.debug  '%s %s found in both %s and %s; skipping the %s version' %
                          [name.to_s.capitalize, instance.name, other.class.name, instance.class.name, instance.class.name]
            next
          end
          provider_instances[instance.name] = instance

          result = new(name: instance.name, provider: instance)

          [properties + parameters].flatten.each do |prop_klass|
            prop_name = prop_klass

            next if [:name, :provider].include?(prop_name)

            if prop_klass.is_a?(Class)
              prop_name = prop_klass.name
            end

            current = instance.send(prop_name)

            prop = result.newattr(prop_klass)

            # initialize each property based on Provider's instance data
            prop.value = current if current
          end

          result
        end
      end

      @instances = type_instances.flatten.compact
    end
  end
end
