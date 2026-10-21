FactoryBot.define do
  factory :event do
    sequence(:title) { |n| "TokyuRuby会議#{n}" }
    sequence(:slug) { |n| "event-#{n}" }
    held_on { Date.new(2026, 10, 18) }
    status { :preparing }
  end
end
