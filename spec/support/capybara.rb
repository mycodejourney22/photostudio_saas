# spec/support/capybara.rb
Capybara.configure do |config|
  config.default_max_wait_time = 5
  config.default_normalize_ws = true
  config.always_include_port = true
  config.server_port = 3001
end

# Chrome headless driver for JS tests
Capybara.register_driver :selenium_webdriver_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# spec/support/shoulda_matchers.rb
require 'shoulda/matchers'

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
