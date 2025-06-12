# spec/factories/appointments.rb (Enhanced)
FactoryBot.define do
  factory :appointment do
    tenant
    customer
    user
    studio
    scheduled_at { 1.day.from_now }
    duration_minutes { 60 }
    price { 200 }
    session_type { 'portrait' }
    status { 'pending' }
    notes { "Test appointment" }

    trait :today do
      scheduled_at { Time.current.beginning_of_day + 10.hours }
    end

    trait :confirmed do
      status { 'confirmed' }
    end

    trait :completed do
      status { 'completed' }
      scheduled_at { 1.day.ago }
    end
  end
end
