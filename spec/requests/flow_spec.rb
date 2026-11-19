require "rails_helper"

RSpec.describe "画面の導線", type: :request do
  let(:event) { create(:event, status: :open) }
  let!(:food) { create(:category, category_name: :food) }
  let!(:talk_category) { create(:category, category_name: :talk) }
  let(:user) { create(:user) }

  before { sign_in(user) }

  # 一覧の中で、そのエントリーの詳細へ向かうリンクの文言
  def entry_link_texts(entry)
    path = event_entry_path(event.slug, entry, category: "food")
    Nokogiri::HTML(response.body).css("main a[href='#{path}']").map { |link| link.text.strip }
  end

  it "投票の部門選択にはLT王を並べ、talks へ送る" do
    get event_votes_categories_path(event.slug)

    expect(response.body).to include(event_entries_path(event.slug, category: "food"))
    expect(response.body).to include(event_talks_path(event.slug))
  end

  it "投票すると投票完了画面へ送り、残票を出す" do
    entry = create(:entry, event: event, category: food)

    post event_votes_path(event.slug), params: { vote: { entry_id: entry.id } }

    expect(response).to redirect_to event_votes_completions_path(event.slug, category: "food")
    follow_redirect!
    expect(response.body).to include("投票が完了しました").and include("残り 2 票")
  end

  it "票を使い切ると続けて投票する導線を出さない" do
    3.times { post event_votes_path(event.slug), params: { vote: { entry_id: create(:entry, event: event, category: food).id } } }

    follow_redirect!
    expect(response.body).to include("3票分すべての投票が完了しました")
  end

  it "LT王に投票すると専用の完了画面へ送る" do
    talk = create(:talk, event: event)

    post event_talk_votes_path(event.slug), params: { talk_vote: { talk_id: talk.id } }

    expect(response).to redirect_to event_talk_votes_completions_path(event.slug)
    follow_redirect!
    expect(response.body).to include("投票が完了しました")
  end

  it "投票先を選ぶ画面に投票済みのエントリーを出す" do
    entry = create(:entry, event: event, category: food, title: "唐揚げ")
    post event_votes_path(event.slug), params: { vote: { entry_id: entry.id } }

    get event_entries_path(event.slug, category: "food")

    expect(response.body).to include("あなたが投票したのは以下のエントリーです").and include("唐揚げ")
  end

  it "自分のエントリーには選択するではなく、詳細へ行ける自分の作品バッジを出す" do
    own = create(:entry, event: event, category: food, user: user, title: "唐揚げ")
    other = create(:entry, event: event, category: food, title: "ポテトサラダ")

    get event_entries_path(event.slug, category: "food")

    expect(response.body).to include("自分の作品")
    expect(entry_link_texts(own)).to eq([ "自分の作品" ])
    expect(entry_link_texts(other)).to eq([ "選択する" ])
  end

  it "自分のエントリーの詳細では投票フォームを出さない" do
    entry = create(:entry, event: event, category: food, user: user)

    get event_entry_path(event.slug, entry, category: "food")

    expect(response.body).to include("自分のエントリーには投票できません")
    expect(response.body).not_to include("投票する（残り")
  end

  it "投票済みのエントリーには選択するではなく、詳細へ行ける投票済みバッジを出す" do
    voted = create(:entry, event: event, category: food, title: "唐揚げ")
    other = create(:entry, event: event, category: food, title: "ポテトサラダ")
    post event_votes_path(event.slug), params: { vote: { entry_id: voted.id } }

    get event_entries_path(event.slug, category: "food")

    expect(response.body).to include("投票済み")
    expect(entry_link_texts(voted)).to eq([ "投票済み" ])
    expect(entry_link_texts(other)).to eq([ "選択する" ])
  end

  it "投票済みのエントリーの詳細では投票フォームを出さない" do
    entry = create(:entry, event: event, category: food)
    post event_votes_path(event.slug), params: { vote: { entry_id: entry.id } }

    get event_entry_path(event.slug, entry, category: "food")

    expect(response.body).to include("このエントリーには投票済みです")
    expect(response.body).not_to include("投票する（残り")
  end

  it "投票済みのLTには選択するではなく、詳細へ行ける投票済みバッジを出す" do
    voted = create(:talk, event: event)
    other = create(:talk, event: event)
    post event_talk_votes_path(event.slug), params: { talk_vote: { talk_id: voted.id } }

    get event_talks_path(event.slug)

    link_texts = ->(talk) { Nokogiri::HTML(response.body).css("main a[href='#{event_talk_path(event.slug, talk)}']").map { |link| link.text.strip } }
    expect(link_texts.call(voted)).to eq([ "投票済み" ])
    expect(link_texts.call(other)).to eq([ "選択する" ])
  end

  it "LTの説明を一覧と詳細にエスケープして表示し、空欄なら表示しない" do
    talk = create(:talk, event: event, description: "1行目\n<script>内容</script>")
    empty = create(:talk, event: event, description: nil)

    get event_talks_path(event.slug)
    expect(response.body).to include("<p class=\"mb-2 line-clamp-10 text-xs break-words text-tokyu-ink-soft last:mb-0\">1行目\n&lt;script&gt;内容&lt;/script&gt;</p>")
    expect(response.body.scan('class="mb-2 line-clamp-10 text-xs break-words text-tokyu-ink-soft last:mb-0"').size).to eq 1

    # 余白などの class を変えても壊れないよう、詳細カードの中身で確かめる
    get event_talk_path(event.slug, talk)
    card = Nokogiri::HTML(response.body).at_css("main .card")
    expect(card.css("p").map(&:text)).to include("1行目\n<script>内容</script>")
    expect(card.at_css("script")).to be_nil

    get event_talk_path(event.slug, empty)
    card = Nokogiri::HTML(response.body).at_css("main .card")
    expect(card.css("p").map(&:text)).to eq([ "「#{empty.title}」", empty.user_name ])
  end

  it "発表資料のリンクを一覧と詳細に安全に表示する" do
    talk = create(:talk, event: event, slide_url: "https://example.com/slides?a=1&b=2")
    empty = create(:talk, event: event)
    invalid = create(:talk, event: event)
    invalid.update_column(:slide_url, "javascript:alert(1)")

    get event_talks_path(event.slug)
    expect(response.body).to include('href="https://example.com/slides?a=1&amp;b=2"', 'target="_blank"', 'rel="noopener noreferrer"')
    expect(response.body.scan(">発表資料</a>").size).to eq 1
    expect(response.body).not_to include("javascript:alert(1)")

    get event_talk_path(event.slug, talk)
    expect(response.body).to include('href="https://example.com/slides?a=1&amp;b=2"', 'target="_blank"', 'rel="noopener noreferrer"', ">発表資料</a>")
    [ empty, invalid ].each do |item|
      get event_talk_path(event.slug, item)
      expect(response.body).not_to include(">発表資料</a>", "javascript:alert(1)")
    end
  end

  it "投票の完了画面はLT王を受け付けない" do
    get event_votes_completions_path(event.slug, category: "talk")

    expect(response).to have_http_status(:not_found)
  end

  it "投票の完了画面は未知の部門名を受け付けない" do
    get event_votes_completions_path(event.slug, category: "beer")

    expect(response).to have_http_status(:not_found)
  end

  it "エントリーの完了画面はLT王を受け付けない" do
    get event_entries_completions_path(event.slug, category: "talk")

    expect(response).to have_http_status(:not_found)
  end

  it "準備中は部門選択も完了画面も開けない" do
    event.preparing!

    get event_votes_categories_path(event.slug)

    expect(response).to have_http_status(:forbidden)
  end
end
