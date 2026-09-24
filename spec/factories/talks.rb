FactoryBot.define do
  factory :talk do
    event
    sequence(:user_name) { |n| "登壇者#{n}" }
    sequence(:title) { |n| "LT#{n}" }
    status { :scheduled }
  end
end
