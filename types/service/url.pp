type Openstack::Service::Url  = Hash[
  Enum['public', 'internal', 'admin'],
  Variant[
    Stdlib::HTTPUrl,
    Stdlib::HTTPSUrl
  ],
  3
]
