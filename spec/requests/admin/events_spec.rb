require "rails_helper"

RSpec.describe "イベント管理", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }

  it "管理者はステータスを変更できる" do
    sign_in(admin)

    patch admin_event_path(event), params: { event: { status: "open" } }

    expect(event.reload).to be_open
  end

  it "管理者は集計中になると集計を確認できる" do
    event.update!(status: :counting)
    food = create(:category, category_name: :food)
    create(:category, category_name: :drink)
    create(:category, category_name: :talk)
    entry = create(:entry, event: event, category: food, title: "唐揚げ")
    create(:vote, user: create(:user), entry: entry)
    talk = create(:talk, event: event, title: "Ruby の話")
    create(:talk_vote, user: create(:user), talk: talk)
    sign_in(admin)

    get admin_event_path(event)

    expect(response.body).to include("飯王（単品王）", "唐揚げ", "飯王（合算王）", "LT王（単品王）", "Ruby の話")
  end

  it "公開中のあいだは管理者にも集計を見せない" do
    event.update!(status: :open)
    food = create(:category, category_name: :food)
    create(:vote, user: create(:user), entry: create(:entry, event: event, category: food, title: "唐揚げ"))
    sign_in(admin)

    get admin_event_path(event)

    expect(response.body).to include("ステータスを 集計中 にすると表示されます。")
    expect(response.body).not_to include("唐揚げ")
  end

  it "一般ユーザーは管理画面に入れない" do
    sign_in(create(:user))

    get admin_events_path

    expect(response).to redirect_to root_path
  end

  it "未ログインでは管理画面に入れない" do
    get admin_events_path

    expect(response).to redirect_to login_path
  end
end
