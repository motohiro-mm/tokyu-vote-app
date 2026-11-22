require "rails_helper"

RSpec.describe "結果画面", type: :request do
  let(:event) { create(:event, status: :closed) }
  let(:food) { create(:category, category_name: :food) }

  before { sign_in(create(:user)) }

  it "結果公開ではランキングとコメントを出す" do
    entry = create(:entry, event: event, category: food, title: "唐揚げ")
    create(:vote, entry: entry, comment: "おいしかった")

    get event_results_path(event.slug, category: "food")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("飯王（単品王）", "飯王（合算王）", "唐揚げ", "おいしかった")
  end

  it "ランキングとコメントの作品名から、その作品の結果へ行ける" do
    entry = create(:entry, event: event, category: food, title: "唐揚げ")
    other = create(:entry, event: event, category: food, user: entry.user, title: "ポテトサラダ")
    create(:vote, entry: entry, comment: "おいしかった")
    create(:vote, entry: other)

    get event_results_path(event.slug, category: "food")

    # 単品王・合算王・コメントの3か所から同じ画面へリンクする
    expect(response.body.scan(%(href="#{event_entry_result_path(event.slug, entry)}")).size).to eq 3
    expect(response.body).to include(event_entry_result_path(event.slug, other))
  end

  it "LT王のランキングとコメントから、そのLTの結果へ行ける" do
    create(:category, category_name: :talk)
    talk = create(:talk, event: event, title: "Ruby の話")
    create(:talk_vote, talk: talk, comment: "よかった")

    get event_results_path(event.slug, category: "talk")

    expect(response.body.scan(%(href="#{event_talk_result_path(event.slug, talk)}")).size).to eq 2
  end

  describe "作品ごとの結果" do
    it "作品と入った順位、その作品へのコメントを出し、結果一覧へ戻れる" do
      entry = create(:entry, event: event, category: food, title: "唐揚げ", description: "祖母のレシピ")
      other = create(:entry, event: event, category: food, title: "ポテトサラダ")
      create(:vote, entry: entry, comment: "おいしかった")
      create(:vote, entry: entry)
      create(:vote, entry: other, comment: "ほかの作品へのコメント")

      get event_entry_result_path(event.slug, entry)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("飯王の結果", "唐揚げ", "祖母のレシピ", "飯王（単品王）", "飯王（合算王）", "1位", "2票", "おいしかった")
      expect(response.body).not_to include("ほかの作品へのコメント", "投票する")
      expect(response.body).to include(ERB::Util.html_escape(event_results_path(event.slug, category: "food")))
    end

    it "3位までに入らなかった作品は順位を出さない" do
      entry = create(:entry, event: event, category: food, title: "唐揚げ")

      get event_entry_result_path(event.slug, entry)

      expect(response.body).not_to include("順位")
      expect(response.body).to include("コメントはありませんでした。")
    end

    it "ほかのイベントの作品は 404 にする" do
      entry = create(:entry, event: create(:event, status: :closed), category: food)

      get event_entry_result_path(event.slug, entry)

      expect(response).to have_http_status(:not_found)
    end

    it "公開中は見せない" do
      entry = create(:entry, event: event, category: food)
      event.open!

      get event_entry_result_path(event.slug, entry)

      expect(response).to redirect_to event_path(event.slug)
    end
  end

  describe "LTごとの結果" do
    before { create(:category, category_name: :talk) }

    it "LTの順位とコメントを出す" do
      talk = create(:talk, event: event, title: "Ruby の話")
      create(:talk_vote, talk: talk, comment: "よかった")

      get event_talk_result_path(event.slug, talk)

      expect(response.body).to include("LT王の結果", "Ruby の話", "LT王", "1位", "よかった")
      expect(response.body).not_to include("合算王")
    end

    it "キャンセルされたLTは 404 にする" do
      talk = create(:talk, event: event, status: :canceled)

      get event_talk_result_path(event.slug, talk)

      expect(response).to have_http_status(:not_found)
    end
  end

  it "終了したイベントの結果はアーカイブへ送る" do
    event.finished!
    create(:entry, event: event, category: food, title: "唐揚げ")

    get event_results_path(event.slug, category: "food")

    expect(response).to redirect_to("/archives/#{event.slug}/results?category=food")
  end

  it "投票者の名前は出さない" do
    voter = create(:user, name: "ないしょのひと")
    create(:vote, user: voter, entry: create(:entry, event: event, category: food), comment: "おいしかった")

    get event_results_path(event.slug, category: "food")

    expect(response.body).not_to include("ないしょのひと")
  end

  it "LT王の結果を出す" do
    create(:category, category_name: :talk)
    create(:talk_vote, talk: create(:talk, event: event, title: "Ruby の話", slide_url: "https://example.com/slides"), comment: "よかった")

    get event_results_path(event.slug, category: "talk")

    expect(response.body).to include("LT王", "Ruby の話", "よかった")
    expect(response.body).not_to include("発表資料", "https://example.com/slides")
  end

  it "イベント画面から各部門の結果へ行ける" do
    food
    create(:category, category_name: :talk)

    get event_path(event.slug)

    expect(response.body).to include(event_results_path(event.slug, category: "food"))
    expect(response.body).to include(event_results_path(event.slug, category: "talk"))
  end

  it "公開中は結果を見せない" do
    event.open!

    get event_results_path(event.slug, category: "food")

    expect(response).to redirect_to event_path(event.slug)
  end

  it "集計中は結果を見せない" do
    event.counting!

    get event_results_path(event.slug, category: "food")

    expect(response).to have_http_status(:forbidden)
  end

  it "未知の部門は 404 にする" do
    get event_results_path(event.slug, category: "sweets")

    expect(response).to have_http_status(:not_found)
  end
end
