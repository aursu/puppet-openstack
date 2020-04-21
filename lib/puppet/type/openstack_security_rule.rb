$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/openstack/customtype'
require 'puppet_x/openstack/customprop'

Puppet::Type.newtype(:openstack_security_rule) do
  include CustomType

  @doc = <<-PUPPET
    @summary
      A security group rule specifies the network access rules for servers and
      other resources on the network.
    PUPPET

  ensurable

  newparam(:name, namevar: true) do
    desc 'Security group rule name in format [<project>/]<group>/<direction>/<proto>/<remote>/<range>'
  end

  newparam(:project, namevar: true) do
    desc "Owner's project (name or ID)"

    defaultto ''

    validate do |value|
      raise ArgumentError, _('Project name or ID must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

      next if value.to_s == ''

      project = resource.project_instance(value) || resource.project_resource(value)
      raise ArgumentError, _("Project #{value} must be defined in catalog or exist in OpenStack environment") unless project
    end
  end

  newparam(:group) do
    desc 'Create rule in this security group (name or ID)'

    validate do |value|
      raise ArgumentError, _('Security group name or ID must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

      group = resource.security_group_instance(value) || resource.security_group_resource(value)
      raise ArgumentError, _("Security group #{value} must be defined in catalog or exist in OpenStack environment") unless project
    end
  end

  newparam(:direction) do
    desc 'Rule applies to incoming or outgoing network traffic (default)'

    newvalues(:ingress, :egress)
    defaultto :ingress
  end

  newparam(:protocol) do
    desc <<-PUPPET
    IP protocol (icmp, tcp, udp; default: tcp)

    Compute version 2

    IP protocol (ah, dccp, egp, esp, gre, icmp, igmp, ipv6-encap, ipv6-frag, ipv6-icmp, ipv6-nonxt, ipv6-opts, ipv6-route, ospf, pgm, rsvp, sctp, tcp, udp, udplite, vrrp and integer representations [0-255] or any; default: any (all protocols))

    Network version 2
    PUPPET

    validate do |value|
      raise ArgumentError, _('Protocol name or ID must be a String, Integer or :any not %{klass}') % { klass: value.class } unless value.is_a?(String) || value.is_a?(Integer) || value.to_s == 'any'

      next if value.to_s == 'any'
      next if %w[ah dccp egp esp gre icmp igmp ipv6-encap ipv6-frag ipv6-icmp ipv6-nonxt ipv6-opts ipv6-route ospf pgm rsvp sctp tcp udp udplite vrrp].include? value.to_s
      next if (0 .. 255).include? value.to_i

      raise ArgumentError, _("Protocol #{value} must be ah, dccp, egp, esp, gre, icmp, igmp, ipv6-encap, ipv6-frag, ipv6-icmp, ipv6-nonxt, ipv6-opts, ipv6-route, ospf, pgm, rsvp, sctp, tcp, udp, udplite, vrrp and integer representations [0-255] or any; default: any (all protocols)")
    end
  end

  newparam(:remote_ip) do
    desc <<-PUPPET
    Remote IP address block (may use CIDR notation; default for IPv4 rule: 0.0.0.0/0, default for IPv6 rule: ::/0)
    PUPPET

    validate do |value|
      raise ArgumentError, _('Remote IP address must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)
      raise ArgumentError, _("Remote IP address #{value} must be a valid IP address") unless resource.validate_ip(value)
    end
  end

  newparam(:remote_group) do
    desc 'Remote security group (name or ID)'

    validate do |value|
      raise ArgumentError, _('Remote security group name or ID must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

      group = resource.security_group_instance(value) || resource.security_group_resource(value)
      raise ArgumentError, _("Remote security group #{value} must be defined in catalog or exist in OpenStack environment") unless project
    end
  end

  newparam(:port_range) do
    desc <<-PUPPET
    Destination port, may be a single port or a starting and ending port range: 137:139. Required for IP protocols TCP and UDP.
    ICMP type and code for ICMP IP protocols
    PUPPET

    validate do |value|
      raise ArgumentError, _('Destination port range must be a String not %{klass}') % { klass: value.class } unless value.is_a?(String)

      next if value.to_s == 'any'
      next if value.to_s =~ %r{^type=\d+$}
      next if value.to_s =~ %r{^type=\d+:code=\d+$}
      next if value.to_s =~ %r{^\d+:\d+$}

      raise ArgumentError, _("Destination port range or ICMP type and code #{value} must be a port range (<start>:<end>), ICMP type and optional code (type=<ICMP type>[:code=<ICMP code>]) or :any")
    end
  end

  newparam(:description) do
    desc 'Security rule description'
  end

  autorequire(:openstack_security_group) do
    rv = [self[:group]]
    rv << self[:remote_group] if self[:remote_group]
    rv
  end

  def validate_ip(ip, name = 'IP address')
    IPAddr.new(ip) if ip
  rescue ArgumentError
    raise Puppet::Error, _("'%{ip}' is an invalid %{name}") % { ip: ip, name: name }, $ERROR_INFO
  end
end
