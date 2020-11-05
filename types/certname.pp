type Openstack::CertName = Struct[{
    com                     => String,
    Optional[email_address] => String,
    Optional[unit]          => Variant[String, Array[String]],
    Optional[org]           => Variant[String, Array[String]],
    Optional[loc]           => String,
    Optional[state]         => String,
    Optional[country]       => String,
  }]
