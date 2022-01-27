require 'json'
require 'shellwords'
require 'puppet_x/openstack/apiclient'

# OpenStack client
class Facter::Util::OpenstackClient
  def initialize
    @conf = nil
    @env = nil
    @token_expire = Time.now
    @token = nil
  end

  def openrc_file
    @conf ||= if File.exist?('/root/.openrc')
                '/root/.openrc'
              elsif File.exist?('/etc/keystone/admin-openrc.sh')
                '/etc/keystone/admin-openrc.sh'
              else
                nil
              end
    @conf
  end

  def auth_env
    return @env if @env
    return nil unless openrc_file

    @env = nil

    # read file content and remove shell quotes
    data = File.open(@conf).readlines.map { |l| Puppet::Util::Execution.execute("echo #{l}") }

    # translate file data into OpenStack env variables hash
    env = data.map { |l| l.sub('export', '').strip }
              .map { |e| e.split('=', 2) }
              .select { |k, _v| k.include?('OS_') }

    @env = Hash[env]
  end

  # send request 'req' to server described by URI 'uri'
  def req_submit(uri, req, limit = 5)
    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      read_timeout: 5,
      open_timeout: 5,
    ) do |http|
      http.request(req) do |res|
        return res.code, res.to_hash, res.body if res.is_a?(Net::HTTPSuccess)

        if res.is_a?(Net::HTTPRedirection)
          # stop redirection loop
          return nil if limit.zero?

          # follow redirection
          url = res['location']
          return req_submit(URI(url), req, limit - 1)
        end

        return res.code, res.to_hash, nil
      end
    end
  rescue SocketError, Net::OpenTimeout
    Puppet.warning "URL #{uri} fetch error"
    nil
  end

  # use HTTP GET request to the server
  def url_get(url, header = {})
    uri = URI(url)
    req = Net::HTTP::Get.new(uri, header)

    req_submit(uri, req)
  end

  # use HTTP POST request to the server
  def url_post(url, data, header = { 'Content-Type' => 'application/json' })
    uri = URI(url)
    req = Net::HTTP::Post.new(uri, header)
    req.body = data

    req_submit(uri, req)
  end

  def api_url(request_uri)
    return nil unless auth_env

    api_auth   = auth_env['OS_AUTH_URL']
    api_uri    = URI(api_auth)
    api_host   = api_uri.host
    api_scheme = api_uri.scheme

    case request_uri
    when 'flavors', 'flavors/detail'
      api = "#{api_scheme}://#{api_host}:8774/v2.1"
    when 'networks', 'ports', 'security-groups', 'security-group-rules', 'routers', 'subnets', 'floatingips'
      api = "#{api_scheme}://#{api_host}:9696/v2.0"
    else
      api = api_auth
    end

    "#{api}/#{request_uri}"
  end

  def auth_object
    {
      auth: {
        identity: {
          methods: ['password'],
          password: {
            user: {
              name: @env['OS_USERNAME'],
              password: @env['OS_PASSWORD'],
              domain: { name: @env['OS_USER_DOMAIN_NAME'] },
            },
          },
        },
        scope: {
          system: { all: true },
        },
      },
    }
  end

  def auth_token
    return @token if @token && @token_expire > Time.now

    tokens_url = api_url('auth/tokens')
    return nil unless tokens_url

    _code, header, body = url_post(tokens_url, auth_object.to_json)
    body_hash          = JSON.parse(body) if body
    expires_at         = body_hash['token']['expires_at'] if body_hash.is_a?(Hash) && body_hash['token'].is_a?(Hash)

    @token_expire = Time.parse(expires_at)
    @token        = header['x-subject-token'][0]
  end

  def api_get(request_uri)
    url = api_url(request_uri)

    return {} unless url

    _code, _header, body = url_get(url, 'X-Auth-Token' => auth_token)
    body_hash = JSON.parse(body) if body

    return body_hash if body_hash.is_a?(Hash)
    {}
  end

  def api_get_list_array(request_uri, object_list = nil)
    body_hash = api_get(request_uri)

    object_list = request_uri unless object_list

    return body_hash[object_list] if body_hash.is_a?(Hash) && body_hash[object_list]
    []
  end

  def api_get_list(request_uri, object_list = nil, key = 'name', filter = [])
    ret = {}
    jout = api_get_list_array(request_uri, object_list)
    jout.each do |p|
      if key.is_a?(Array)
        idx = key.map { |i| p[i] }.join(':')
        ret[idx] = p.reject { |k, _v| filter.include?(k.to_sym) }
      else
        idx = p[key]
        ret[idx] = p.reject { |k, _v| k == key || filter.include?(k.to_sym) }
      end
    end
    ret
  end
end

Facter.add(:openstack, type: :aggregate) do
  confine { File.exist? '/etc/keystone/admin-openrc.sh' }

  # osclient = Facter::Util::OpenstackClient.new
  osclient = PuppetX::OpenStack::APIClient.new

  chunk(:cycle) do
    openstack = {}
    maj = Facter.value(:os_nova_version).to_i
    if maj > 0
      openstack[:cycle] = {
        14 => 'newton',
        15 => 'ocata',
        16 => 'pike',
        17 => 'queens',
        18 => 'rocky',
        19 => 'stein',
        20 => 'train',
        21 => 'ussuri',
        22 => 'victoria',
        23 => 'wallaby',
        24 => 'xena',
        25 => 'yoga',
      }[maj]
    end
    openstack
  end

  chunk(:domains) do
    osclient.req_params = {)
    { 'domains' => osclient.api_get_list('domains') }
  end

  chunk(:flavors) do
    osclient.req_params = { is_public: 'none' }
    { 'flavors' => osclient.api_get_list('flavors/detail', 'flavors') }
  end

  chunk(:networks) do
    osclient.req_params = {)
    { 'networks' => osclient.api_get_list('networks') }
  end

  chunk(:projects) do
    osclient.req_params = {)
    { 'projects' => osclient.api_get_list('projects') }
  end

  chunk(:routers) do
    osclient.req_params = {)
    { 'routers' => osclient.api_get_list('routers') }
  end

  chunk(:subnets) do
    osclient.req_params = {)
    { 'subnets' => osclient.api_get_list('subnets') }
  end

  chunk(:users) do
    osclient.req_params = {)
    { 'users' => osclient.api_get_list('users') }
  end

  chunk(:roles) do
    osclient.req_params = {)
    { 'roles' => osclient.api_get_list('roles') }
  end

  chunk(:floatingips) do
    osclient.req_params = {)
    { 'floatingips' => osclient.api_get_list_array('floatingips') }
  end
end

Facter.add(:octavia, type: :aggregate) do
  confine { File.exist? '/etc/keystone/admin-openrc.sh' }

  # osclient = Facter::Util::OpenstackClient.new
  osclient = PuppetX::OpenStack::APIClient.new

  chunk(:networks) do
    Facter.value(:openstack)['networks'].select { |net, _| net == 'lb-mgmt-net' }
  end

  chunk(:subnets) do
    Facter.value(:openstack)['subnets'].select { |subnet, _| subnet == 'lb-mgmt-subnet' }
  end

  chunk(:ports) do
    osclient.req_params = {)
    osclient.api_get_list_array('ports').select { |port| port['name'] == 'octavia-health-manager-listen-port' }
  end

  # https://docs.openstack.org/octavia/latest/install/install-ubuntu.html
  aggregate do |chunks|
    summary = chunks

    net = chunks[:networks]['lb-mgmt-net']
    if net
      netid = net['id']
      summary[:NETID] = netid
      if netid
        summary[:BRNAME] = 'brq' + netid[0...11]
      end
    end

    subnet = chunks[:subnets]['lb-mgmt-subnet']
    if subnet
      summary[:SUBNET_ID] = subnet['id']
    end

    port = chunks[:ports][0]
    if port
      summary[:MGMT_PORT_ID] = port['id']
      summary[:MGMT_PORT_MAC] = port['mac_address']
    end

    summary
  end
end
