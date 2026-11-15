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
    talk = create(:talk, event: event, title: "初めてのLT", user_name: "登壇者")
    create(:vote, user: user, entry: past_entry)
    create(:vote, user: user, entry: food)
    create(:vote, user: user, entry: drink)
    create(:talk_vote, user: user, talk: talk)
    past_event.update!(status: :finished)

    other_user = create(:user)
    create(:vote, user: other_user, entry: create(:entry, event: event, title: "他の人が選んだ料理"))
    create(:talk_vote, user: other_user, talk: create(:talk, event: event, title: "他の人が選んだLT"))

    sign_in(user)
    get event_path(event)
    expect(Nokogiri::HTML(response.body).at_css("header a[href='#{mypage_path}']")&.text).to eq("マイページ")

    get mypage_path, params: { user_id: other_user.id }

    expect(response).to have_http_status(:ok)
    current_section, past_section = Nokogiri::HTML(response.body).css("main section")
    expect(current_section.text).to include("今回の会議", "飯王", "手作り餃子", food.user.name,
                                            "酒王", "梅酒", "LT王", "初めてのLT", "登壇者")
    expect(past_section.text).to include("前回の会議", "飯王", "前回のカレー")
    expect(response.body).not_to include("他の人が選んだ料理", "他の人が選んだLT")
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
