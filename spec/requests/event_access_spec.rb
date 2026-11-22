require "rails_helper"

RSpec.describe "スラッグで指定したイベントへのアクセス", type: :request do
  before do
    create(:category, category_name: :food)
    create(:category, category_name: :talk)
  end

  def public_paths(event)
    [
      event_path(event.slug),
      event_results_path(event.slug, category: "food"),
      event_entries_path(event.slug, category: "food"),
      event_entries_categories_path(event.slug),
      event_talks_path(event.slug),
      event_votes_categories_path(event.slug),
      event_talk_votes_completions_path(event.slug)
    ]
  end

  it "結果公開中でも、作品ごと・LTごとの結果はログイン前ならログイン画面へ送る" do
    event = create(:event, status: :closed)
    entry = create(:entry, event: event, category: Category.find_by_name!(:food))
    talk = create(:talk, event: event)

    [ event_entry_result_path(event.slug, entry), event_talk_result_path(event.slug, talk) ].each do |path|
      get path

      expect(response).to redirect_to(login_path), path
    end
  end

  it "終了したイベントはログイン前にアーカイブへ送る" do
    event = create(:event, status: :finished, slug: "16")

    public_paths(event).each do |path|
      get path

      expect(response).to redirect_to(path.sub("/events/", "/archives/")), path
    end
  end

  it "別の回の受付が始まっても結果公開中の回の結果を見られる" do
    sign_in(create(:user))
    older = create(:event, status: :closed, slug: "16", created_at: 1.day.ago)
    create(:event, status: :open, slug: "17")

    get event_results_path(older.slug, category: "food")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(older.title, "飯王（単品王）")
  end

  it "次回を準備中にしても受付中の回を表示して投票できる" do
    sign_in(create(:user))
    open_event = create(:event, status: :open, slug: "16", created_at: 1.day.ago)
    next_event = create(:event, status: :preparing, slug: "17")
    entry = create(:entry, event: open_event, category: Category.find_by!(category_name: :food))

    get root_path
    expect(response).to redirect_to(event_path(open_event.slug))

    get event_path(open_event.slug)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(open_event.title)

    get event_path(next_event.slug)
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("準備中です")

    expect {
      post event_votes_path(open_event.slug), params: { vote: { entry_id: entry.id } }
    }.to change(Vote, :count).by(1)
    expect(response).to redirect_to(event_votes_completions_path(open_event.slug, category: "food"))
  end

  it "未知の下位パスも終了済みの回はアーカイブへ送り受付中の回は404にする" do
    older = create(:event, status: :finished, slug: "16")
    create(:event, status: :open, slug: "17")

    head "/events/#{older.slug}/unknown/path?x=1"
    expect(response).to redirect_to("/archives/16/unknown/path?x=1")

    sign_in(create(:user))
    get "/events/17/unknown/path"
    expect(response).to have_http_status(:not_found)
  end

  it "終了済みの回への更新リクエストは404にする" do
    create(:event, status: :finished, slug: "16")
    post "/events/16/votes", params: { vote: { entry_id: 1 } }
    expect(response).to have_http_status(:not_found)
  end

  it "管理画面では終了したイベントを見られる" do
    event = create(:event, status: :finished, title: "終わった回")
    sign_in(create(:user, :admin))

    get admin_event_path(event)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("終わった回")
  end

  it "管理画面では古いイベントを見られる" do
    older = create(:event, status: :closed, title: "前の回", created_at: 1.day.ago)
    create(:event, status: :open)
    sign_in(create(:user, :admin))

    get admin_event_path(older)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("前の回")
  end
end
