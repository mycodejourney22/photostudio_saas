# spec/system/tenant_registration_flow_spec.rb
require 'rails_helper'

RSpec.describe "Tenant Registration Flow", type: :system do
  before do
    driven_by(:rack_test)
  end

  describe "Creating a new studio" do
    it "successfully creates and verifies a tenant" do
      # Visit main site
      visit "http://localhost:3000"
      expect(page).to have_content("Create Your Photography Studio")

      # Fill out registration form
      fill_in "tenant[name]", with: "Test Photography Studio"
      fill_in "tenant[subdomain]", with: "test-studio"
      fill_in "tenant[email]", with: "studio@test.com"

      # Owner information
      fill_in "user[first_name]", with: "John"
      fill_in "user[last_name]", with: "Doe"
      fill_in "user[email]", with: "john@teststudio.com"
      fill_in "user[password]", with: "password123"
      fill_in "user[password_confirmation]", with: "password123"

      click_button "Create Studio Account"

      # Should show success page
      expect(page).to have_content("Studio Created Successfully!")
      expect(page).to have_content("test-studio.photostudio.com")

      # Verify tenant was created
      tenant = Tenant.find_by(subdomain: "test-studio")
      expect(tenant).to be_present
      expect(tenant.status).to eq("pending")
      expect(tenant.verification_token).to be_present

      # Simulate email verification
      visit tenant_registration_verify_path(token: tenant.verification_token)
      expect(page).to have_content("Studio Verified!")

      # Verify tenant is now active
      tenant.reload
      expect(tenant.status).to eq("active")
      expect(tenant.verified_at).to be_present
    end

    it "validates required fields" do
      visit "http://localhost:3000"

      click_button "Create Studio Account"

      expect(page).to have_content("Please fix the following errors:")
    end

    it "prevents duplicate subdomains" do
      create(:tenant, subdomain: "existing-studio")

      visit "http://localhost:3000"

      fill_in "tenant[name]", with: "Another Studio"
      fill_in "tenant[subdomain]", with: "existing-studio"
      fill_in "tenant[email]", with: "another@test.com"

      fill_in "user[first_name]", with: "Jane"
      fill_in "user[last_name]", with: "Smith"
      fill_in "user[email]", with: "jane@test.com"
      fill_in "user[password]", with: "password123"
      fill_in "user[password_confirmation]", with: "password123"

      click_button "Create Studio Account"

      expect(page).to have_content("Subdomain has already been taken")
    end
  end
end
