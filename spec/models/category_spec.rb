require "rails_helper"

RSpec.describe Category do
  it "未知の部門名は見つからない部門として扱う" do
    create(:category, category_name: :food)

    expect(described_class.find_by_name!("food")).to be_food
    expect { described_class.find_by_name!("beer") }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "部門はLT王を含む3つ" do
    expect(described_class.category_names.keys).to eq %w[food drink talk]
  end

  it "for_entries はLT王を外す" do
    food = create(:category, category_name: :food)
    create(:category, category_name: :talk)

    expect(described_class.for_entries).to contain_exactly(food)
  end
end
