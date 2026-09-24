require "rails_helper"

RSpec.describe "エントリー", type: :request do
  let(:event) { create(:event, status: :open) }
  let!(:food) { create(:category, category_name: :food) }
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "登録できる" do
    expect {
      post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }
    }.to change(Entry, :count).by(1)
  end

  it "登録すると登録完了画面へ送る" do
    post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }

    expect(response).to redirect_to event_entries_completions_path(event, category: "food")
    follow_redirect!
    expect(response.body).to include("登録が完了しました")
  end

  it "部門選択にはLT王を並べない" do
    create(:category, category_name: :talk)

    get event_entries_categories_path(event)

    expect(response.body).to include(new_event_entry_path(event, category: "food"))
    expect(response.body).not_to include(new_event_entry_path(event, category: "talk"))
  end

  it "登録済みの作品を出す" do
    create(:entry, event: event, category: food, user: user, title: "唐揚げ")

    get new_event_entry_path(event, category: "food")

    expect(response.body).to include("登録済みの作品").and include("唐揚げ")
  end

  it "受付前は登録できない" do
    event.preparing!

    expect {
      post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }
    }.not_to change(Entry, :count)
  end

  it "LT王の部門は扱わない" do
    create(:category, category_name: :talk)

    get new_event_entry_path(event, category: "talk")

    expect(response).to have_http_status(:not_found)
  end

  it "未知の部門名は見つからない" do
    get new_event_entry_path(event, category: "beer")

    expect(response).to have_http_status(:not_found)
  end
end
