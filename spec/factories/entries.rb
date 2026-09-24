FactoryBot.define do
  factory :entry do
    user
    event
    category
    sequence(:title) { |n| "持ち寄り#{n}" }
  end
end
