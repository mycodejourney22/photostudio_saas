class TenantResolver
  def self.resolve(request)
    subdomain = extract_subdomain(request.host)
    return nil unless subdomain

    Tenant.find_by(subdomain: subdomain, status: 'active')
  end

  private

  def self.extract_subdomain(host)
    parts = host.split('.')
    return nil if parts.length < 2

    # Handle localhost and custom domains
    return parts.first if parts.length >= 3

    nil
  end
end
