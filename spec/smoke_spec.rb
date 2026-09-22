require "rails_helper"

RSpec.describe "アプリの起動" do
  it "Rails と DB の設定が読み込める" do
    expect(Rails.env).to eq("test")
    expect(ActiveRecord::Base.connection.adapter_name).to eq("SQLite")
  end
end
