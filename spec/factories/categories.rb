FactoryBot.define do
  factory :category do
    category_name { :food }

    initialize_with { Category.find_or_initialize_by(category_name: category_name) }
  end
end
