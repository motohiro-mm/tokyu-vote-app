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

  it "終了したイベントは飛ばして最新のイベントへ送る" do
    event
    create(:event, status: :finished)

    get root_path

    expect(response).to redirect_to event_path(event)
  end

  it "イベントが無ければ案内を出す" do
    get root_path

    expect(response.body).to include("開催中のイベントはありません")
  end

  it "終了したイベントしか無ければ案内を出す" do
    create(:event, status: :finished)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("開催中のイベントはありません")
  end

  it "終了したイベントはURLを知っていれば結果への導線を見られる" do
    create(:category, category_name: :food)
    event.finished!

    get event_path(event)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(event_results_path(event, category: "food"))
    expect(response.body).not_to include(event_votes_categories_path(event))
  end

  it "回次のURLでそのイベントの画面を開く" do
    event.update!(slug: "17", held_on: Date.new(2026, 10, 18), title: "第17回の投票")

    get "/17"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("第17回の投票")
    expect(response.body).to include(I18n.l(Date.new(2026, 10, 18), format: :long))
    expect(response.body).to include(event_entries_categories_path(event))
  end

  it "数値IDのURLでも同じ画面を開く" do
    event.update!(slug: "17", title: "第17回の投票")

    get event_path(event)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("第17回の投票")
  end

  it "存在しない回次は見つからない" do
    get "/99"

    expect(response).to have_http_status(:not_found)
  end

  it "予約パスは回次URLにしない" do
    event.update!(slug: "17", title: "第17回の投票")

    get "/login"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("第17回の投票")

    get "/up"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("第17回の投票")

    %w[logout terms privacy admin auth events].each do |path|
      get "/#{path}"
      expect(response.body).not_to include("第17回の投票")
    end
  end

  it "利用規約とプライバシーポリシーはログイン不要" do
    delete logout_path

    get terms_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("第1条（適用）", "第10条（準拠法）")

    get privacy_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("1. 取得する情報", "GitHubアカウントの識別子（ユーザーID）")
  end
end
