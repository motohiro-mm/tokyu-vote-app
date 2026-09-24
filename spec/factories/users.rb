FactoryBot.define do
  factory :user do
    provider { "github" }
    sequence(:uid) { |n| n.to_s }
    sequence(:name) { |n| "user#{n}" }

    trait :admin do
      admin { true }
    end
  end
end
