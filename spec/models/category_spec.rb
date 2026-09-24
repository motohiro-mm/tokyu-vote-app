require "rails_helper"

RSpec.describe Category do
  it "未知の部門名は見つからない部門として扱う" do
    create(:category, category_name: :food)

    expect(described_class.find_by_name!("food")).to be_food
    expect { described_class.find_by_name!("beer") }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "投票対象のモデルは部門によって違う" do
    expect(create(:category, category_name: :food).votable_model).to eq Entry
    expect(create(:category, category_name: :lt).votable_model).to eq Talk
  end
end
