# spec/system/dashboard_spec.rb
require 'rails_helper'

RSpec.describe "Dashboard", type: :system do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :confirmed) }
  let!(:tenant_user) { create(:tenant_user, tenant: tenant, user: user, role: 'owner') }

  before do
    driven_by(:rack_test)
    ActsAsTenant.with_tenant(tenant) do
      # Create test data
      @customer1 = create(:customer, tenant: tenant, first_name: "Alice", last_name: "Smith")
      @customer2 = create(:customer, tenant: tenant, first_name: "Bob", last_name: "Jones")

      @studio = create(:studio, tenant: tenant, name: "Studio A")

      # Today's appointments
      @today_appointment = create(:appointment,
        tenant: tenant,
        customer: @customer1,
        user: user,
        studio: @studio,
        scheduled_at: Time.current.beginning_of_day + 10.hours,
        status: 'confirmed',
        price: 200
      )

      # Past appointments for revenue calculation
      create(:appointment,
        tenant: tenant,
        customer: @customer2,
        user: user,
        scheduled_at: 3.days.ago,
        status: 'completed',
        price: 150
      )
    end

    sign_in_as(user, tenant)
  end

  describe "Dashboard display" do
    it "shows welcome message and studio name" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      expect(page).to have_content("Welcome back, #{user.first_name}!")
      expect(page).to have_content(tenant.name)
      expect(page).to have_content("Dashboard")
    end

    it "displays stats cards with correct data" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      # Should show today's bookings
      expect(page).to have_content("Today's Bookings")
      expect(page).to have_content("1") # One appointment today

      # Should show week's revenue (from past appointments)
      expect(page).to have_content("Week's Revenue")

      # Should show active customers
      expect(page).to have_content("Active Customers")
      expect(page).to have_content("2") # Two customers created

      # Should show customer satisfaction
      expect(page).to have_content("Satisfaction")
      expect(page).to have_content("98%")
    end

    it "shows today's schedule" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      within("[data-testid='todays-schedule']", match: :first) do
        expect(page).to have_content("Today's Schedule")
        expect(page).to have_content(@customer1.full_name)
        expect(page).to have_content("10:00 AM")
        expect(page).to have_content("$200")
        expect(page).to have_content("Confirmed")
      end
    end

    it "shows usage statistics" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      expect(page).to have_content("Quick Stats")
      expect(page).to have_content("Bookings")
      expect(page).to have_content("Storage Used")
      expect(page).to have_content("Team Members")
    end

    it "displays quick action buttons" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      expect(page).to have_link("New Booking")
      expect(page).to have_link("Add Customer")
      expect(page).to have_link("View Customers")
      expect(page).to have_link("All Bookings")
    end
  end

  describe "Navigation" do
    it "shows sidebar navigation with all menu items" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      # Check main navigation items
      expect(page).to have_link("Dashboard")
      expect(page).to have_link("Appointments")
      expect(page).to have_link("Customers")
      expect(page).to have_link("Studios")

      # Admin/Owner specific items
      expect(page).to have_link("Settings")
      expect(page).to have_link("Branding")
    end

    it "navigates to appointments page" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      click_link "Appointments"

      expect(current_path).to eq("/appointments")
    end

    it "navigates to customers page" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      click_link "Customers"

      expect(current_path).to eq("/customers")
    end
  end

  describe "Mobile responsive behavior" do
    it "shows mobile menu button on small screens", js: true do
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone size

      visit "http://#{tenant.subdomain}.localhost:3000/"

      expect(page).to have_css('[data-action="mobile-navigation#toggleMenu"]')
    end
  end

  describe "Empty state" do
    it "shows empty state when no appointments today" do
      ActsAsTenant.with_tenant(tenant) do
        Appointment.destroy_all
      end

      visit "http://#{tenant.subdomain}.localhost:3000/"

      expect(page).to have_content("No appointments scheduled for today")
      expect(page).to have_link("Schedule First Appointment")
    end
  end
end
