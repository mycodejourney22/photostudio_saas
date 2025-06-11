class TenantConstraint
  def matches?(request)
    subdomain = request.subdomains.first

    return false if subdomain.blank?
    return false if subdomain.in?(%w[www api admin assets])

    # Check if tenant exists and is active
    Rails.cache.fetch("tenant_exists:#{subdomain}", expires_in: 5.minutes) do
      Tenant.exists?(subdomain: subdomain, status: 'active')
    end
  end
end
