require 'json'
require 'shellwords'

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
    when 'flavors'
      api = "#{api_scheme}://#{api_host}:8774/v2.1"
    when 'networks', 'ports', 'security-groups', 'security-group-rules', 'routers', 'subnets'
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

    return nil unless url

    _code, _header, body = url_get(url, 'X-Auth-Token' => auth_token)
    body_hash = JSON.parse(body) if body

    return body_hash if body_hash.is_a?(Hash)
    nil
  end

  def api_get_list_array(request_uri, object_list = nil)
    body_hash = api_get(request_uri)

    object_list = request_uri unless object_list

    return body_hash[object_list] if body_hash.is_a?(Hash)
    nil
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

  osclient = Facter::Util::OpenstackClient.new

  chunk(:cycle) do
    openstack = {}
    if Puppet::Util.which('nova-manage')
      nova_version = Puppet::Util::Execution.execute('nova-manage --version', combine: true)

      m = %r{^(\d+)}.match(nova_version)
      maj = m[0].to_i

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
      }[maj]
    end
    openstack
  end

  chunk(:domains) do
    { 'domains' => osclient.api_get_list('domains') }
  end

  chunk(:flavors) do
    { 'flavors' => osclient.api_get_list('flavors') }
  end

  chunk(:networks) do
    { 'networks' => osclient.api_get_list('networks') }
  end

  chunk(:ports) do
    { 'ports' => osclient.api_get_list_array('ports') }
  end

  chunk(:projects) do
    { 'projects' => osclient.api_get_list('projects') }
  end

  chunk(:routers) do
    { 'routers' => osclient.api_get_list('routers') }
  end

  chunk(:security_groups) do
    { 'security_groups' => osclient.api_get_list_array('security-groups', 'security_groups') }
  end

  chunk(:security_group_rules, require: :security_groups) do
    { 'security_group_rules' => osclient.api_get_list_array('security-group-rules', 'security_group_rules') }
  end

  chunk(:subnets) do
    { 'subnets' => osclient.api_get_list('subnets') }
  end

  chunk(:users) do
    { 'users' => osclient.api_get_list_array('users') }
  end

  chunk(:roles) do
    { 'roles' => osclient.api_get_list('roles') }
  end

  chunk(:floatingips) do
    { 'floatingips' => osclient.api_get_list_array('floatingips') }
  end
end
