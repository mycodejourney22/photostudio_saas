# spec/factories/studios.rb (Enhanced)
FactoryBot.define do
  factory :studio do
    tenant
    name { "Studio A" }
    location { "Main Floor" }
    description { "Professional photography studio" }
    capacity { 4 }
    equipment { "Lighting, backdrops, props" }
    active { true }
  end
end
