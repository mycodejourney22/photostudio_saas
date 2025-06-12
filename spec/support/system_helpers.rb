# spec/support/system_helpers.rb
module SystemHelpers
  def sign_in_as(user, tenant)
    visit "http://#{tenant.subdomain}.localhost:3000/users/sign_in"
    fill_in "user[email]", with: user.email
    fill_in "user[password]", with: "password123"
    click_button "Sign In"
  end
end

RSpec.configure do |config|
  config.include SystemHelpers, type: :system
end
