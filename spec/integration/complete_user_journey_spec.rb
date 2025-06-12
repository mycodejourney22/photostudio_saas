# spec/integration/complete_user_journey_spec.rb
require 'rails_helper'

RSpec.describe "Complete User Journey", type: :system do
  before do
    driven_by(:rack_test)
  end

  it "completes full signup to dashboard workflow" do
    # Step 1: Visit main site and create studio
    visit "http://localhost:3000"
    expect(page).to have_content("Create Your Photography Studio")

    fill_in "tenant[name]", with: "Journey Test Studio"
    fill_in "tenant[subdomain]", with: "journey-test"
    fill_in "tenant[email]", with: "journey@test.com"

    fill_in "user[first_name]", with: "Test"
    fill_in "user[last_name]", with: "Owner"
    fill_in "user[email]", with: "owner@journey.com"
    fill_in "user[password]", with: "password123"
    fill_in "user[password_confirmation]", with: "password123"

    click_button "Create Studio Account"
    expect(page).to have_content("Studio Created Successfully!")

    # Step 2: Verify email (simulate)
    tenant = Tenant.find_by(subdomain: "journey-test")
    visit tenant_registration_verify_path(token: tenant.verification_token)
    expect(page).to have_content("Studio Verified!")

    # Step 3: Sign in to the studio
    visit "http://journey-test.localhost:3000/users/sign_in"
    fill_in "user[email]", with: "owner@journey.com"
    fill_in "user[password]", with: "password123"
    click_button "Sign In"

    # Step 4: Verify dashboard loads correctly
    expect(page).to have_content("Welcome back, Test!")
    expect(page).to have_content("Journey Test Studio")
    expect(page).to have_content("Today's Bookings")
    expect(page).to have_content("0") # No bookings yet

    # Step 5: Navigate and verify sidebar works
    expect(page).to have_link("Dashboard")
    expect(page).to have_link("Appointments")
    expect(page).to have_link("Customers")

    # Step 6: Check quick actions work
    expect(page).to have_link("New Booking")
    expect(page).to have_link("Add Customer")

    # Step 7: Test navigation
    click_link "Customers"
    expect(current_path).to eq("/customers")

    # Step 8: Test logout
    find('[data-controller="dropdown"]').click
    click_link "Sign Out"
    expect(page).to have_content("Sign in to your studio dashboard")
  end
end
