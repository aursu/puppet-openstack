require 'puppet/parameter/boolean'

# Provides common properties and parameters for OpenStack CLI
module OpenstackCustomComm
  def self.extended(base)
    base.newparam(:auth_project_domain_name) do
      desc 'Domain name containing project (Env: OS_PROJECT_DOMAIN_NAME)'
    end

    base.newparam(:auth_user_domain_name) do
      desc "User's domain name (Env: OS_USER_DOMAIN_NAME)"
    end

    base.newparam(:auth_project_name) do
      desc 'Project name to scope to (Env: OS_PROJECT_NAME)'
    end

    base.newparam(:auth_username) do
      desc 'Username (Env: OS_USERNAME)'
    end

    base.newparam(:auth_password) do
      desc "User's password (Env: OS_PASSWORD)"
    end

    base.newparam(:auth_url) do
      desc 'Authentication URL (Env: OS_AUTH_URL)'
    end

    base.newparam(:identity_api_version) do
      desc 'Identity API version, default=3 (Env: OS_IDENTITY_API_VERSION)'

      validate do |value|
        next if value == :absent
        if value.to_s !~ %r{^\d+$}
          raise Puppet::Error, 'Identity API version must be a positive integer'
        end
      end
    end

    base.newparam(:image_api_version) do
      desc 'Image API version, default=2 (Env: OS_IMAGE_API_VERSION)'

      validate do |value|
        next if value == :absent
        if value.to_s !~ %r{^\d+$}
          raise Puppet::Error, 'Image API version must be a positive integer'
        end
      end
    end
  end
end # of newtype
