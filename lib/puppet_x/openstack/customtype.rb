module CustomType
  class << self
    def included(base)
      base.extend ClassMethods
    end
  end

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
            next if prop_name == :name || prop_name == :provider

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
