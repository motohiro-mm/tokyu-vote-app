require "rails_helper"

RSpec.describe "マイページ", type: :request do
  it "未ログインならログイン画面へ送る" do
    get mypage_path

    expect(response).to redirect_to(login_path)
  end

  it "本人の投票先だけを開催回と部門ごとに表示する" do
    user = create(:user)
    past_event = create(:event, status: :open, title: "前回の会議", created_at: 1.month.ago)
    event = create(:event, status: :open, title: "今回の会議")
    past_entry = create(:entry, event: past_event, title: "前回のカレー")
    food = create(:entry, event: event, title: "手作り餃子")
    drink = create(:entry, event: event, category: create(:category, category_name: :drink), title: "梅酒")
    create(:category, category_name: :talk)
    talk = create(:talk, event: event, title: "初めてのLT", user_name: "登壇者")
    create(:vote, user: user, entry: past_entry)
    create(:vote, user: user, entry: food, comment: "餃子の感想\nまた食べたい")
    create(:vote, user: user, entry: drink)
    create(:talk_vote, user: user, talk: talk, comment: "LTの感想")
    past_event.update!(status: :finished)

    other_user = create(:user)
    create(:vote, user: other_user, entry: create(:entry, event: event, title: "他の人が選んだ料理"))
    create(:talk_vote, user: other_user, talk: create(:talk, event: event, title: "他の人が選んだLT"))
    create(:vote, user: other_user, entry: food, comment: "他の人のコメント")

    sign_in(user)
    get event_path(event)
    expect(Nokogiri::HTML(response.body).at_css("header a[href='#{mypage_path}']")&.text).to eq("マイページ")

    get mypage_path, params: { user_id: other_user.id }

    expect(response).to have_http_status(:ok)
    current_section, past_section = Nokogiri::HTML(response.body).css("main article")
    expect(current_section.text).to include("今回の会議", "飯王", "手作り餃子", food.user.name,
                                            "酒王", "梅酒", "LT王", "初めてのLT", "登壇者", "餃子の感想\nまた食べたい", "LTの感想")
    expect(past_section.text).to include("前回の会議", "飯王", "前回のカレー")
    expect(past_section.at_css("a")["href"]).to eq(event_entry_path(past_event, past_entry, category: :food))
    expect(response.body).not_to include("他の人が選んだ料理", "他の人が選んだLT", "他の人のコメント")

    expected_links = [
      event_entry_path(event, food, category: :food),
      event_entry_path(event, drink, category: :drink),
      event_talk_path(event, talk)
    ]
    expect(current_section.css("a").map { |link| link["href"] }).to eq(expected_links)
    expected_links.each do |path|
      get path
      expect(response).to have_http_status(:ok)
    end

    event.counting!
    get mypage_path
    current_section = Nokogiri::HTML(response.body).at_css("main article")
    expect(current_section.text).to include("手作り餃子", "LTの感想")
    expect(current_section.css("a")).to be_empty
  end

  it "本人が登録したアイテムを表示し、詳細を開ける" do
    user = create(:user)
    event = create(:event, status: :open)
    entry = create(:entry, user: user, event: event, title: "自家製プリン", description: "カラメルはほろ苦め")
    create(:entry, event: event, title: "他の人のプリン")
    sign_in(user)

    get mypage_path

    expect(response).to have_http_status(:ok)
    section = Nokogiri::HTML(response.body).at_css("main article")
    expect(section.text).to include(event.title, "飯王")
    expect(section.text).not_to include("他の人のプリン")
    expect(section.at_css("a").text).to eq("自家製プリン")

    get section.at_css("a")["href"]
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("カラメルはほろ苦め")
  end

  it "取り消した票が消え、投票先がなければ空の状態を表示する" do
    user = create(:user)
    event = create(:event, status: :open)
    vote = create(:vote, user: user, entry: create(:entry, event: event, title: "取り消した料理"))
    talk_vote = create(:talk_vote, user: user, talk: create(:talk, event: event, title: "取り消したLT"))
    sign_in(user)

    delete event_vote_path(event, vote)
    delete event_talk_vote_path(event, talk_vote)
    get mypage_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("まだ投票していません。")
    expect(response.body).not_to include("取り消した料理", "取り消したLT")
  end
end
