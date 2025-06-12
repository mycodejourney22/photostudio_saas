# spec/factories/users.rb (Enhanced)
FactoryBot.define do
  factory :user do
    first_name { "John" }
    last_name { "Doe" }
    sequence(:email) { |n| "user#{n}@test.com" }
    password { "password123" }
    password_confirmation { "password123" }
    phone { "+1234567890" }
    active { true }

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :super_admin do
      super_admin { true }
    end
  end
end
