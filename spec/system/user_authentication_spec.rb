# spec/system/user_authentication_spec.rb
require 'rails_helper'

RSpec.describe "User Authentication", type: :system do
  let(:tenant) { create(:tenant, :active) }
  let(:user) { create(:user, :confirmed) }
  let!(:tenant_user) { create(:tenant_user, tenant: tenant, user: user, role: 'owner') }

  before do
    driven_by(:rack_test)
  end

  describe "User login" do
    it "successfully logs in with valid credentials" do
      visit "http://#{tenant.subdomain}.localhost:3000/users/sign_in"

      expect(page).to have_content(tenant.name)
      expect(page).to have_content("Sign in to your studio dashboard")

      fill_in "user[email]", with: user.email
      fill_in "user[password]", with: "password123"

      click_button "Sign In"

      expect(page).to have_content("Welcome back, #{user.first_name}!")
      expect(page).to have_content("Dashboard")
      expect(current_path).to eq("/")
    end

    it "shows error for invalid credentials" do
      visit "http://#{tenant.subdomain}.localhost:3000/users/sign_in"

      fill_in "user[email]", with: user.email
      fill_in "user[password]", with: "wrongpassword"

      click_button "Sign In"

      expect(page).to have_content("Invalid Email or password")
    end

    it "redirects non-tenant users" do
      other_user = create(:user, :confirmed)

      visit "http://#{tenant.subdomain}.localhost:3000/users/sign_in"

      fill_in "user[email]", with: other_user.email
      fill_in "user[password]", with: "password123"

      click_button "Sign In"

      expect(page).to have_content("Access denied to this studio")
    end

    it "handles remember me functionality" do
      visit "http://#{tenant.subdomain}.localhost:3000/users/sign_in"

      fill_in "user[email]", with: user.email
      fill_in "user[password]", with: "password123"
      check "user[remember_me]"

      click_button "Sign In"

      expect(page).to have_content("Welcome back")
    end
  end

  describe "User logout" do
    before do
      sign_in_as(user, tenant)
    end

    it "successfully logs out user" do
      visit "http://#{tenant.subdomain}.localhost:3000/"

      # Find and click user menu
      find('[data-controller="dropdown"]').click
      click_link "Sign Out"

      expect(page).to have_content("Sign in to your studio dashboard")
      expect(current_path).to eq("/users/sign_in")
    end
  end
end
