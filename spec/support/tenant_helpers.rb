# spec/support/tenant_helpers.rb
module TenantHelpers
  def with_tenant(tenant, &block)
    ActsAsTenant.with_tenant(tenant, &block)
  end

  def set_current_tenant(tenant)
    ActsAsTenant.current_tenant = tenant
  end

  def clear_current_tenant
    ActsAsTenant.current_tenant = nil
  end
end

RSpec.configure do |config|
  config.include TenantHelpers
end
