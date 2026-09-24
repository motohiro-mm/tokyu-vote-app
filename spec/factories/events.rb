FactoryBot.define do
  factory :event do
    sequence(:title) { |n| "TokyuRuby会議#{n}" }
    status { :preparing }
  end
end
