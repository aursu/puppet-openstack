#
module CustomType
  class << self
    def included(base)
      base.extend ClassMethods

      base.newparam(:validation) do
        desc 'Apply type instance validation or not'
      end
    end
  end

  def prop_to_array(prop)
    [prop].flatten.reject { |p| p.to_s == 'absent' }.compact
  end

  def entity_instance(lookup_id, entity_type, lookup_key = nil)
    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id

    instances = Puppet::Type.type(entity_type).instances
                            .select { |r| [lookup_key ? r[lookup_key] : nil, r[:name], r[:id]].compact.include?(lookup_id) }
    return nil if instances.empty?

    instances.first
  end

  def entity_resource(lookup_id, entity_type, lookup_key = nil)
    # bugfix: catalog does not exist while instances prefetch
    return nil unless catalog

    lookup_id = lookup_id.is_a?(Array) ? lookup_id.first : lookup_id
    catalog.resources.find { |r| r.is_a?(Puppet::Type.type(entity_type)) && [lookup_key ? r[lookup_key] : nil, r[:name], r[:id]].compact.include?(lookup_id) }
  end

  def domain_instance(lookup_id)
    entity_instance(lookup_id, :openstack_domain)
  end

  def domain_resource(lookup_id)
    entity_resource(lookup_id, :openstack_domain)
  end

  def project_instance(lookup_id)
    entity_instance(lookup_id, :openstack_project, :project_name)
  end

  def project_resource(lookup_id)
    entity_resource(lookup_id, :openstack_project, :project_name)
  end

  def network_instance(lookup_id)
    entity_instance(lookup_id, :openstack_network)
  end

  def network_resource(lookup_id)
    entity_resource(lookup_id, :openstack_network)
  end

  def subnet_instance(lookup_id)
    entity_instance(lookup_id, :openstack_subnet)
  end

  def subnet_resource(lookup_id)
    entity_resource(lookup_id, :openstack_subnet)
  end

  def role_instance(lookup_id)
    entity_instance(lookup_id, :openstack_role)
  end

  def role_resource(lookup_id)
    entity_resource(lookup_id, :openstack_role)
  end

  def user_instance(lookup_id)
    entity_instance(lookup_id, :openstack_user)
  end

  def user_resource(lookup_id)
    entity_resource(lookup_id, :openstack_user)
  end

  def security_group_instance(lookup_id)
    entity_instance(lookup_id, :openstack_security_group, :group_name)
  end

  def security_group_resource(lookup_id)
    entity_resource(lookup_id, :openstack_security_group, :group_name)
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

          result = new(name: instance.name, provider: instance, validation: :false)

          [properties + parameters].flatten.each do |prop_klass|
            prop_name = prop_klass

            next if [:name, :provider].include?(prop_name)

            prop_name = prop_klass.name if prop_klass.is_a?(Class)
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
