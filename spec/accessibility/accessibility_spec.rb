# spec/accessibility/accessibility_spec.rb
require 'rails_helper'

RSpec.describe "Accessibility", type: :system do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :confirmed) }
  let!(:tenant_user) { create(:tenant_user, tenant: tenant, user: user, role: 'owner') }

  before do
    sign_in_as(user, tenant)
  end

  describe "Dashboard accessibility" do
    it "has proper heading structure" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      # Should have h1 for main heading
      expect(page).to have_css('h1', text: /Welcome back/)

      # Should have h2 for section headings
      expect(page).to have_css('h2', text: "Today's Schedule")
      expect(page).to have_css('h2', text: "Quick Stats")
    end

    it "has proper form labels" do
      visit "http://#{tenant.subdomain}.localhost:3000/users/sign_in"

      expect(page).to have_css('label[for*="email"]')
      expect(page).to have_css('label[for*="password"]')
    end

    it "has proper button text" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      # Buttons should have descriptive text
      expect(page).to have_button("New Booking")
      expect(page).to have_button("Add Customer")
    end
  end
end
