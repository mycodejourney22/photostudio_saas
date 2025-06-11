class TenantSetupJob < ApplicationJob
  def perform(tenant_id)
    tenant = Tenant.find(tenant_id)

    # Create apartment schema
    Apartment::Tenant.create(tenant.subdomain)

    # Setup default data
    ActsAsTenant.with_tenant(tenant) do
      create_default_studios(tenant)
      create_sample_data(tenant) if Rails.env.development?
    end

    # Send welcome email
    TenantMailer.welcome_email(tenant).deliver_now
  end

  private

  def create_default_studios(tenant)
    tenant.studios.create!(
      name: 'Main Studio',
      location: 'Studio A',
      capacity: 4,
      equipment: 'Professional lighting, backdrop, props'
    )
  end

  def create_sample_data(tenant)
    # Create sample customers and appointments for demo
  end
end
