require "rails_helper"

RSpec.describe "イベント画面", type: :request do
  let(:event) { create(:event, status: :open) }
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "エントリーと投票の2つの導線を出す" do
    get event_path(event)

    expect(response.body).to include(event_entries_categories_path(event))
    expect(response.body).to include(event_votes_categories_path(event))
  end

  it "結果公開では投票の導線を出さない" do
    event.closed!

    get event_path(event)

    expect(response.body).not_to include(event_votes_categories_path(event))
  end

  it "準備中は専用の画面で止める" do
    event.preparing!

    get event_path(event)

    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("準備中です")
  end

  it "集計中は専用の画面で止める" do
    event.counting!

    get event_path(event)

    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("集計中です")
  end

  it "未ログインではログイン画面へ送る" do
    event
    delete logout_path

    get event_path(event)

    expect(response).to redirect_to login_path
  end

  it "最新のイベントへ送る" do
    event

    get root_path

    expect(response).to redirect_to event_path(event)
  end

  it "イベントが無ければ案内を出す" do
    get root_path

    expect(response.body).to include("イベントがありません")
  end

  it "利用規約とプライバシーポリシーはログイン不要" do
    delete logout_path

    get terms_path
    expect(response).to have_http_status(:ok)

    get privacy_path
    expect(response).to have_http_status(:ok)
  end
end
