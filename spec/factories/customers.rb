FactoryBot.define do
  factory :customer do
    tenant { nil }
    first_name { "MyString" }
    last_name { "MyString" }
    email { "MyString" }
    phone { "MyString" }
    address { "MyText" }
    city { "MyString" }
    state { "MyString" }
    zip_code { "MyString" }
    country { "MyString" }
    date_of_birth { "2025-06-11" }
    notes { "MyText" }
    preferences { "MyText" }
    active { false }
    metadata { "" }
  end
end
