# spec/factories/tenants.rb (Enhanced)
FactoryBot.define do
  factory :tenant do
    name { "Test Photography Studio" }
    sequence(:subdomain) { |n| "test-studio-#{n}" }
    sequence(:email) { |n| "studio#{n}@test.com" }
    plan_type { 'professional' }
    status { 'pending' }
    verification_token { SecureRandom.urlsafe_base64(32) }

    trait :active do
      status { 'active' }
      verified_at { Time.current }
    end

    trait :suspended do
      status { 'suspended' }
    end

    after(:create) do |tenant|
      tenant.create_branding!(
        primary_color: '#667eea',
        secondary_color: '#764ba2',
        font_family: 'Inter',
        welcome_message: "Welcome to #{tenant.name}!"
      ) unless tenant.branding
    end
  end
end
