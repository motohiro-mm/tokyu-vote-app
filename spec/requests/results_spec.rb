require "rails_helper"

RSpec.describe "結果画面", type: :request do
  let(:event) { create(:event, status: :closed) }
  let(:food) { create(:category, category_name: :food) }

  before { sign_in(create(:user)) }

  it "結果公開ではランキングとコメントを出す" do
    entry = create(:entry, event: event, category: food, title: "唐揚げ")
    create(:vote, entry: entry, comment: "おいしかった")

    get event_results_path(event, category: "food")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("飯王（単品王）", "飯王（合算王）", "唐揚げ", "おいしかった")
  end

  it "投票者の名前は出さない" do
    voter = create(:user, name: "ないしょのひと")
    create(:vote, user: voter, entry: create(:entry, event: event, category: food), comment: "おいしかった")

    get event_results_path(event, category: "food")

    expect(response.body).not_to include("ないしょのひと")
  end

  it "LT王の結果を出す" do
    create(:category, category_name: :talk)
    create(:talk_vote, talk: create(:talk, event: event, title: "Ruby の話"), comment: "よかった")

    get event_results_path(event, category: "talk")

    expect(response.body).to include("LT王（単品王）", "Ruby の話", "よかった")
  end

  it "イベント画面から各部門の結果へ行ける" do
    food
    create(:category, category_name: :talk)

    get event_path(event)

    expect(response.body).to include(event_results_path(event, category: "food"))
    expect(response.body).to include(event_results_path(event, category: "talk"))
  end

  it "公開中は結果を見せない" do
    event.open!

    get event_results_path(event, category: "food")

    expect(response).to redirect_to event_path(event)
  end

  it "集計中は結果を見せない" do
    event.counting!

    get event_results_path(event, category: "food")

    expect(response).to have_http_status(:forbidden)
  end

  it "未知の部門は 404 にする" do
    get event_results_path(event, category: "sweets")

    expect(response).to have_http_status(:not_found)
  end
end
