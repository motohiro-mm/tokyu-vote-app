require "rails_helper"

RSpec.describe "画面の導線", type: :request do
  let(:event) { create(:event, status: :open) }
  let!(:food) { create(:category, category_name: :food) }
  let!(:talk_category) { create(:category, category_name: :talk) }
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "イベント画面からエントリーと投票の2つに分かれる" do
    get event_path(event)

    expect(response.body).to include(event_entries_categories_path(event))
    expect(response.body).to include(event_votes_categories_path(event))
  end

  it "エントリーの部門選択にはLT王を並べない" do
    get event_entries_categories_path(event)

    expect(response.body).to include(new_event_entry_path(event, category: "food"))
    expect(response.body).not_to include(new_event_entry_path(event, category: "talk"))
  end

  it "投票の部門選択にはLT王を並べ、talks へ送る" do
    get event_votes_categories_path(event)

    expect(response.body).to include(event_entries_path(event, category: "food"))
    expect(response.body).to include(event_talks_path(event))
  end

  it "登録すると登録完了画面へ送る" do
    post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }

    expect(response).to redirect_to event_entries_completions_path(event, category: "food")
    follow_redirect!
    expect(response.body).to include("登録が完了しました")
  end

  it "投票すると投票完了画面へ送り、残票を出す" do
    entry = create(:entry, event: event, category: food)

    post event_votes_path(event), params: { vote: { entry_id: entry.id } }

    expect(response).to redirect_to event_votes_completions_path(event, category: "food")
    follow_redirect!
    expect(response.body).to include("投票が完了しました").and include("残り 2 票")
  end

  it "票を使い切ると続けて投票する導線を出さない" do
    3.times { post event_votes_path(event), params: { vote: { entry_id: create(:entry, event: event, category: food).id } } }

    follow_redirect!
    expect(response.body).to include("3票分すべての投票が完了しました")
  end

  it "LT王に投票すると専用の完了画面へ送る" do
    talk = create(:talk, event: event)

    post event_talk_votes_path(event), params: { talk_vote: { talk_id: talk.id } }

    expect(response).to redirect_to event_talk_votes_completions_path(event)
    follow_redirect!
    expect(response.body).to include("投票が完了しました")
  end

  it "投票先を選ぶ画面に投票済みのエントリーを出す" do
    entry = create(:entry, event: event, category: food, title: "唐揚げ")
    post event_votes_path(event), params: { vote: { entry_id: entry.id } }

    get event_entries_path(event, category: "food")

    expect(response.body).to include("あなたが投票したのは以下のエントリーです").and include("唐揚げ")
  end

  it "投票済みのエントリーには選択するを出さない" do
    voted = create(:entry, event: event, category: food, title: "唐揚げ")
    other = create(:entry, event: event, category: food, title: "ポテトサラダ")
    post event_votes_path(event), params: { vote: { entry_id: voted.id } }

    get event_entries_path(event, category: "food")

    expect(response.body).to include("投票済み")
    expect(response.body).not_to include(event_entry_path(event, voted, category: "food"))
    expect(response.body).to include(event_entry_path(event, other, category: "food"))
  end

  it "投票済みのエントリーの詳細では投票フォームを出さない" do
    entry = create(:entry, event: event, category: food)
    post event_votes_path(event), params: { vote: { entry_id: entry.id } }

    get event_entry_path(event, entry, category: "food")

    expect(response.body).to include("このエントリーには投票済みです")
    expect(response.body).not_to include("投票する（残り")
  end

  it "投票済みのLTには選択するを出さない" do
    voted = create(:talk, event: event)
    other = create(:talk, event: event)
    post event_talk_votes_path(event), params: { talk_vote: { talk_id: voted.id } }

    get event_talks_path(event)

    expect(response.body).to include("投票済み")
    expect(response.body).not_to include(event_talk_path(event, voted))
    expect(response.body).to include(event_talk_path(event, other))
  end

  it "投票の完了画面はLT王を受け付けない" do
    get event_votes_completions_path(event, category: "talk")

    expect(response).to have_http_status(:not_found)
  end

  it "投票の完了画面は未知の部門名を受け付けない" do
    get event_votes_completions_path(event, category: "beer")

    expect(response).to have_http_status(:not_found)
  end

  it "エントリーの完了画面はLT王を受け付けない" do
    get event_entries_completions_path(event, category: "talk")

    expect(response).to have_http_status(:not_found)
  end

  it "準備中は部門選択も完了画面も開けない" do
    event.preparing!

    get event_votes_categories_path(event)

    expect(response).to have_http_status(:forbidden)
  end
end
