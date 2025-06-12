# spec/performance/dashboard_performance_spec.rb
require 'rails_helper'

RSpec.describe "Dashboard Performance", type: :system do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :confirmed) }
  let!(:tenant_user) { create(:tenant_user, tenant: tenant, user: user, role: 'owner') }

  before do
    # Create larger dataset
    ActsAsTenant.with_tenant(tenant) do
      studio = create(:studio, tenant: tenant)

      # Create 50 customers
      customers = create_list(:customer, 50, tenant: tenant)

      # Create 100 appointments across different time ranges
      customers.each do |customer|
        create(:appointment, tenant: tenant, customer: customer, user: user, studio: studio, scheduled_at: rand(30.days).seconds.ago)
        create(:appointment, tenant: tenant, customer: customer, user: user, studio: studio, scheduled_at: rand(30.days).seconds.from_now)
      end
    end

    sign_in_as(user, tenant)
  end

  it "loads dashboard in reasonable time with large dataset" do
    start_time = Time.current

    visit "http://#{tenant.subdomain}.localhost:3000/"

    expect(page).to have_content("Welcome back, #{user.first_name}!")

    load_time = Time.current - start_time
    expect(load_time).to be < 3.seconds # Should load in under 3 seconds
  end

  it "handles stats calculation efficiently" do
    visit "http://#{tenant.subdomain}.localhost:3000/"

    # Should show stats without timing out
    expect(page).to have_content("Today's Bookings")
    expect(page).to have_content("Week's Revenue")
    expect(page).to have_content("Active Customers")
    expect(page).to have_content("50") # Should show customer count
  end
end
