# lib/constraints/tenant_constraint.rb
class TenantConstraint
  def matches?(request)
    subdomain = extract_subdomain(request.host)

    puts "DEBUG: Host = #{request.host}"
    puts "DEBUG: Subdomain = #{subdomain}"

    return false if subdomain.blank?
    return false if subdomain.in?(%w[www api admin assets])

    # Check if tenant exists and is active
    tenant_exists = Rails.cache.fetch("tenant_exists:#{subdomain}", expires_in: 5.minutes) do
      Tenant.exists?(subdomain: subdomain, status: 'active')
    end

    puts "DEBUG: Tenant exists = #{tenant_exists}"
    tenant_exists
  end

  private

  def extract_subdomain(host)
    parts = host.split('.')

    # For localhost development: demo.localhost -> 'demo'
    if host.include?('localhost')
      return parts.first if parts.length >= 2 && parts.first != 'localhost'
    end

    # For production: demo.photostudio.com -> 'demo'
    return parts.first if parts.length >= 3

    nil
  end
end
