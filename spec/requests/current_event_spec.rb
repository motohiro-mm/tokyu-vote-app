require "rails_helper"

RSpec.describe "今のイベント以外", type: :request do
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

  it "終了したイベントはログイン前にアーカイブへ送る" do
    event = create(:event, status: :finished, slug: "16")

    public_paths(event).each do |path|
      get path

      expect(response).to redirect_to(path.sub("/events/", "/archives/")), path
    end
  end

  it "新しいイベントがあるときの古いイベントはアーカイブへ送る" do
    sign_in(create(:user))
    older = create(:event, status: :closed, slug: "16", created_at: 1.day.ago)
    create(:event, status: :open, slug: "17")

    public_paths(older).each do |path|
      get path

      expect(response).to redirect_to(path.sub("/events/", "/archives/")), path
    end
  end

  it "あとから終了した回があっても、終わっていない最新のイベントは見られる" do
    sign_in(create(:user))
    current = create(:event, status: :open, title: "今の回", slug: "16", created_at: 1.day.ago)
    create(:event, status: :finished, slug: "17")

    get event_path(current.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("今の回")
  end

  it "未知の下位パスも過去回はアーカイブへ送り現在の回は404にする" do
    older = create(:event, status: :finished, slug: "16")
    create(:event, status: :open, slug: "17")

    get "/events/#{older.slug}/unknown/path?x=1"
    expect(response).to redirect_to("/archives/16/unknown/path?x=1")

    sign_in(create(:user))
    get "/events/17/unknown/path"
    expect(response).to have_http_status(:not_found)
  end

  it "過去回への更新リクエストをアーカイブへ転送しない" do
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
