Puppet::Functions.create_function(:'openstack::show_resource', Puppet::Functions::InternalFunction) do
  dispatch :openstack_show do
    scope_param
    param 'String', :entity_type
    param 'String', :lookup_id
    optional_param 'String', :lookup_key
  end

  def type_resources(scope, entity_type, lookup_id, lookup_key = nil)
    resources = scope.compiler.resources.select { |r|
      r.type == entity_type &&
      [lookup_key ? r[lookup_key.to_sym] : nil, r[:name], r[:id]].compact.include?(lookup_id)
    }
    return nil if resources.empty?

    return resources.first
  end

  def openstack_show(scope, entity_type, lookup_id, lookup_key = nil)
    resource = type_resources(scope, entity_type.to_sym, lookup_id, lookup_key)

    if resource
      resource.map { |k, v| [k.to_s, v.value] }.to_h
    else
      nil
    end
  end
end
