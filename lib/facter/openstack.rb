require 'json'
require 'shellwords'

class Facter::Util::OpenstackClient
  def initialize
    @conf = nil
    @env = nil
    openstack_command
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
    data = File.open(@conf).readlines
                .map { |l| Puppet::Util::Execution.execute("echo #{l}") }

    # translate file data into OpenStack env variables hash
    env = data.map { |l| l.sub('export', '').strip }
              .map { |e| e.split('=', 2) }
              .select { |k, _v| k =~ %r{OS_} }

    @env = Hash[env]
  end

  def openstack_command(bin = nil)
    cmd = Puppet::Util.which(bin) if bin
    @cmd = if cmd
              cmd
            else
              Puppet::Util.which('openstack')
            end
  end

  def openstack_caller(subcommand, *args)
    # read environment variables for OpenStack authentication
    return nil unless auth_env
    openstack_command unless @cmd

    cmdline = Shellwords.join(args)

    cmd = [@cmd, subcommand, cmdline].compact.join(' ')

    Puppet::Util.withenv(@env) do
      cmdout = Puppet::Util::Execution.execute(cmd)
      return nil if cmdout.nil?
      return nil if cmdout.empty?
      return cmdout
    end
  rescue Puppet::ExecutionFailure => detail
    Puppet.debug "Execution of #{@cmd} command failed: #{detail}"
    false
  end

  def get_list_array(subcommand, long = true, *moreargs)
    args = ['list', '-f', 'json'] + (long ? ['--long'] : [])
    args += moreargs

    cmdout = openstack_caller(subcommand, *args)
    return [] if cmdout.nil?

    jout = JSON.parse(cmdout)
    jout.map do |j|
      j.map { |k, v| [k.downcase.tr(' ', '_'), v] }.to_h
    end
  end

  def get_list(entity, key = 'name', long = true, *args)
    ret = {}
    jout = get_list_array(entity, long, *args)
    jout.each do |p|
      if key.is_a?(Array)
        idx = key.map { |i| p[i] }.join(':')
        ret[idx] = p
      else
        idx = p[key]
        ret[idx] = p.reject { |k, _v| k == key }
      end
    end
    ret
  end

  def req_submit(uri, req, limit = 5)
    begin
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https',
        read_timeout: 5,
        open_timeout: 5
      ) do |http|
        http.request(req) do |res|
          if res.is_a?(Net::HTTPSuccess)
            return res.code, res.to_hash, res.body
          elsif res.is_a?(Net::HTTPRedirection)
            # stop redirection loop
            return nil if limit.zero?

            # follow redirection
            url = res['location']
            return req_submit(URI(url), req, limit - 1)
          else
            return res.code, res.to_hash, nil
          end
        end
      end
    rescue SocketError, Net::OpenTimeout
      Puppet.warning "URL #{uri.to_s} fetch error"
      return nil
    end
  end

  def url_get(url, header = {})
    uri = URI(url)
    req = Net::HTTP::Get.new(uri, header)

    req_submit(uri, req)
  end

  def url_post(url, data, header = { 'Content-Type' => 'application/json' })
    uri = URI(url)
    req = Net::HTTP::Post.new(uri, header)
    req.body = data

    req_submit(uri, req)
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
              domain: { name: @env['OS_USER_DOMAIN_NAME'] }
            }
          }
        },
        scope: {
          system: { all: true }
        }
      }
    }
  end

  def auth_token
    return nil unless auth_env
    return @token if @token && @token_expire > Time.now

    auth_url   = auth_env['OS_AUTH_URL']
    tokens_url = "#{auth_url}/auth/tokens"

    code, header, body = url_post(tokens_url, auth_object.to_json)
    body_hash          = JSON.parse(body) if body
    expires_at         = body_hash['token']['expires_at'] if body_hash.is_a?(Hash) && body_hash['token'].is_a?(Hash)

    @token_expire = Time.parse(expires_at)
    @token        = header['x-subject-token'][0]
  end

  def api_get(request_uri)
    case request_uri
    when 'flavors'
      api = 'http://controller:8774/v2.1'
    when 'networks', 'ports', 'security-groups', 'security-group-rules', 'routers', 'subnets'
      api = 'http://controller:9696/v2.0'
    else
      return nil unless auth_env

      api = auth_env['OS_AUTH_URL']
    end

    url = "#{api}/#{request_uri}"

    code, header, body = url_get(url, { 'X-Auth-Token' => auth_token })
    body_hash          = JSON.parse(body) if body

    return body_hash if body_hash.is_a?(Hash)
    nil
  end

  def api_get_list_array(request_uri, object_list)
    body_hash = api_get(request_uri)
    return body_hash[object_list] if body_hash.is_a?(Hash)
    nil
  end

  def api_get_list(request_uri, object_list, key = 'name', filter = [:links, :tags, :options])
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

Facter.add(:openstack, :type => :aggregate) do
  osclient = Facter::Util::OpenstackClient.new()

  chunk(:cycle) do
    openstack = {}
    if Puppet::Util.which('nova-manage')
      nova_version = Puppet::Util::Execution.execute('nova-manage --version', { :combine => true})

      m = /^(\d+)/.match(nova_version)
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
      }[maj]
    end
    openstack
  end

  chunk(:domain) do
    { 'domain' => osclient.api_get_list('domains', 'domains') }
  end

  chunk(:flavor) do
    { 'flavor' => osclient.api_get_list('flavors', 'flavors') }
  end

  chunk(:network) do
    { 'network' => osclient.api_get_list('networks', 'networks') }
  end

  chunk(:port) do
    { 'port' => osclient.api_get_list_array('ports', 'ports') }
  end

  chunk(:project) do
      { 'project' => osclient.api_get_list('projects', 'projects') }
  end

  chunk(:role) do
    { 'role' => osclient.api_get_list('roles', 'roles') }
  end

  chunk(:router) do
    { 'router' => osclient.api_get_list('routers', 'routers') }
  end

  chunk(:security_group) do
    { 'security_group' => osclient.api_get_list_array('security-groups', 'security_groups') }
  end

  chunk(:security_group_rule, :require => :security_group ) do |group|
    { 'security_group_rule' => osclient.api_get_list_array('security-group-rules', 'security_group_rules') }
  end

  chunk(:subnet) do
    { 'subnet' => osclient.api_get_list('subnets', 'subnets') }
  end

  chunk(:user) do
    { 'user' => osclient.api_get_list_array('users', 'users') }
  end

  chunk(:user_role) do
    { 'user_role' => osclient.api_get_list_array('roles', 'roles') }
  end

  chunk(:floating_ip) do
      { 'floating_ip' => osclient.api_get_list_array('floatingips', 'floatingips') }
  end
end
