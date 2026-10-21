require "rails_helper"

RSpec.describe "今のイベント以外", type: :request do
  before do
    create(:category, category_name: :food)
    create(:category, category_name: :talk)
  end

  def public_paths(event)
    [
      event_path(event),
      "/#{event.slug}",
      event_results_path(event, category: "food"),
      event_entries_path(event, category: "food"),
      event_entries_categories_path(event),
      event_talks_path(event),
      event_votes_categories_path(event),
      event_talk_votes_completions_path(event)
    ]
  end

  it "終了したイベントは一般向けの画面では見つからない" do
    sign_in(create(:user))
    event = create(:event, status: :finished, slug: "16")

    public_paths(event).each do |path|
      get path

      expect(response).to have_http_status(:not_found), path
    end
  end

  it "新しいイベントがあるときの古いイベントは一般向けの画面では見つからない" do
    sign_in(create(:user))
    older = create(:event, status: :closed, slug: "16", created_at: 1.day.ago)
    create(:event, status: :open, slug: "17")

    public_paths(older).each do |path|
      get path

      expect(response).to have_http_status(:not_found), path
    end
  end

  it "あとから終了した回があっても、終わっていない最新のイベントは見られる" do
    sign_in(create(:user))
    current = create(:event, status: :open, title: "今の回", slug: "16", created_at: 1.day.ago)
    create(:event, status: :finished, slug: "17")

    get event_path(current)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("今の回")

    get "/16"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("今の回")
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
