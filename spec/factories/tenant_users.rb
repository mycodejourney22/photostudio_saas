FactoryBot.define do
  factory :tenant_user do
    tenant { nil }
    user { nil }
    role { 1 }
    active { false }
    invitation_token { "MyString" }
  end
end
