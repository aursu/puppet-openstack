Puppet::Functions.create_function(:'openstack::show_instance', Puppet::Functions::InternalFunction) do
  dispatch :openstack_show do
    scope_param
    param 'String', :entity_type
    param 'String', :lookup_id
    optional_param 'String', :lookup_key
  end

  def type_instances(scope, entity_type, lookup_id, lookup_key = nil)

    instances = Puppet::Type.type(entity_type).instances.select { |r|
      [lookup_key ? r[lookup_key] : nil, r[:name], r[:id]].compact.include?(lookup_id)
    }
    return nil if instances.empty?

    return instances.first
  end

  def openstack_show(scope, entity_type, lookup_id, lookup_key = nil)
    resourse = type_instances(scope, entity_type.to_sym, lookup_id, lookup_key)

    if resourse
      resourse.map { |k, v| [k.to_s, v.value] }.to_h
    else
      nil
    end
  end
end
