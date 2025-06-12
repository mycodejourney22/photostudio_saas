module TestDataHelper
  def create_test_tenant_with_data
    tenant = create(:tenant, :active)
    user = create(:user, :confirmed)
    create(:tenant_user, tenant: tenant, user: user, role: 'owner')

    with_tenant(tenant) do
      studio = create(:studio, tenant: tenant)
      customer = create(:customer, tenant: tenant)
      create(:appointment, tenant: tenant, customer: customer, user: user, studio: studio)
    end

    { tenant: tenant, user: user }
  end

  def create_demo_data
    tenant = create(:tenant, :active, name: "Demo Studio", subdomain: "demo-test")
    owner = create(:user, :confirmed, first_name: "Demo", last_name: "Owner")
    create(:tenant_user, tenant: tenant, user: owner, role: 'owner')

    with_tenant(tenant) do
      studio_a = create(:studio, tenant: tenant, name: "Studio A")
      studio_b = create(:studio, tenant: tenant, name: "Studio B")

      customer1 = create(:customer, tenant: tenant, first_name: "Alice", last_name: "Johnson")
      customer2 = create(:customer, tenant: tenant, first_name: "Bob", last_name: "Smith")

      # Today's appointment
      create(:appointment, :today, :confirmed,
        tenant: tenant, customer: customer1, user: owner, studio: studio_a, price: 200
      )

      # Past completed appointment
      create(:appointment, :completed,
        tenant: tenant, customer: customer2, user: owner, studio: studio_b, price: 150
      )
    end

    { tenant: tenant, user: owner }
  end
end

RSpec.configure do |config|
  config.include TestDataHelper
end

# .rspec
--require spec_helper
--format documentation
--color
--order random
