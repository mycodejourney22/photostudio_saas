namespace :test do
  desc "Run core feature tests (signup, login, dashboard)"
  task :core => :environment do
    puts "🧪 Running core feature tests..."

    system("bundle exec rspec spec/system/tenant_registration_flow_spec.rb")
    system("bundle exec rspec spec/system/user_authentication_spec.rb")
    system("bundle exec rspec spec/system/dashboard_spec.rb")

    puts "✅ Core tests completed!"
  end

  desc "Run all model tests"
  task :models => :environment do
    puts "🧪 Running model tests..."
    system("bundle exec rspec spec/models/")
  end

  desc "Run all controller tests"
  task :controllers => :environment do
    puts "🧪 Running controller tests..."
    system("bundle exec rspec spec/controllers/")
  end

  desc "Quick smoke test - just the essentials"
  task :smoke => :environment do
    puts "💨 Running smoke tests..."

    # Test basic model validations
    system("bundle exec rspec spec/models/tenant_spec.rb")
    system("bundle exec rspec spec/models/user_spec.rb")

    # Test authentication flow
    system("bundle exec rspec spec/system/user_authentication_spec.rb")

    puts "✅ Smoke tests completed!"
  end
end
