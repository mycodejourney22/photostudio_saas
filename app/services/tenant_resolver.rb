# app/services/tenant_resolver.rb
class TenantResolver
  def self.resolve(request)
    subdomain = extract_subdomain(request.host)
    return nil unless subdomain

    Rails.logger.debug "TenantResolver: Looking for subdomain '#{subdomain}'"

    tenant = Tenant.find_by(subdomain: subdomain, status: 'active')
    Rails.logger.debug "TenantResolver: Found tenant = #{tenant&.name || 'nil'}"

    tenant
  end

  private

  def self.extract_subdomain(host)
    parts = host.split('.')

    Rails.logger.debug "TenantResolver: Host = #{host}, Parts = #{parts.inspect}"

    if host.include?('localhost')
      return parts.first if parts.length >= 2 && parts.first != 'localhost'
    end

    return parts.first if parts.length >= 3

    nil
  end
end
