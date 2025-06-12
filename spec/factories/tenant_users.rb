# spec/factories/tenant_users.rb (Enhanced)
FactoryBot.define do
  factory :tenant_user do
    tenant
    user
    role { 'staff' }
    active { true }

    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end
  end
end
