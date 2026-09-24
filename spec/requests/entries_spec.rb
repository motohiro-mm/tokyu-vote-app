require "rails_helper"

RSpec.describe "エントリー", type: :request do
  let(:event) { create(:event, status: :open) }
  let!(:food) { create(:category, category_name: :food) }
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "一覧を表示できる" do
    create(:entry, event: event, category: food, title: "唐揚げ")

    get event_entries_path(event, category: "food")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("唐揚げ")
  end

  it "登録できる" do
    expect {
      post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }
    }.to change(Entry, :count).by(1)
  end

  it "受付前は登録できない" do
    event.preparing!

    expect {
      post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }
    }.not_to change(Entry, :count)
  end

  it "LT王の部門は扱わない" do
    create(:category, category_name: :talk)

    get event_entries_path(event, category: "talk")

    expect(response).to have_http_status(:not_found)
  end

  it "未知の部門名は見つからない" do
    get event_entries_path(event, category: "beer")

    expect(response).to have_http_status(:not_found)
  end
end
