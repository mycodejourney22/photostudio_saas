# spec/support/authentication_helpers.rb
module AuthenticationHelpers
  def sign_in_user(user)
    sign_in user
  end

  def sign_out_user
    sign_out :user
  end

  # For system tests
  def sign_in_as(user, tenant)
    visit "http://#{tenant.subdomain}.localhost:3000/users/sign_in"
    fill_in "user[email]", with: user.email
    fill_in "user[password]", with: "password123"
    click_button "Sign In"
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers
end
