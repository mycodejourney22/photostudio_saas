# spec/edge_cases/tenant_edge_cases_spec.rb
require 'rails_helper'

RSpec.describe "Tenant Edge Cases", type: :system do
  describe "Subdomain validation" do
    it "handles special characters in subdomain" do
      visit "http://localhost:3000"

      fill_in "tenant[name]", with: "Test Studio"
      fill_in "tenant[subdomain]", with: "test@studio!"
      fill_in "tenant[email]", with: "test@studio.com"

      # Add user fields
      fill_in "user[first_name]", with: "Test"
      fill_in "user[last_name]", with: "User"
      fill_in "user[email]", with: "user@test.com"
      fill_in "user[password]", with: "password123"
      fill_in "user[password_confirmation]", with: "password123"

      click_button "Create Studio Account"

      expect(page).to have_content("Subdomain is invalid")
    end

    it "handles very long subdomain" do
      visit "http://localhost:3000"

      long_subdomain = "a" * 100

      fill_in "tenant[subdomain]", with: long_subdomain
      # ... fill other fields

      expect do
        click_button "Create Studio Account"
      end.not_to change(Tenant, :count)
    end
  end

  describe "Invalid verification tokens" do
    it "handles expired/invalid tokens gracefully" do
      visit tenant_registration_verify_path(token: "invalid-token-123")

      expect(page).to have_content("Invalid or expired verification link")
      expect(current_path).to eq(new_tenant_registration_path)
    end
  end

  describe "Suspended tenant access" do
    let(:tenant) { create(:tenant, status: 'suspended') }

    it "shows suspended message for suspended tenants" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      expect(page).to have_content("Studio Temporarily Unavailable")
      expect(page).to have_content("suspended")
    end
  end
end
