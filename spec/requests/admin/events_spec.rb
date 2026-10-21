require "rails_helper"

RSpec.describe "イベント管理", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }

  it "管理者はイベントを作成できる" do
    sign_in(admin)

    expect {
      post admin_events_path, params: { event: { title: "TokyuRuby会議99", held_on: "2026-10-18", slug: "99" } }
    }.to change(Event, :count).by(1)
    expect(response).to redirect_to admin_event_path(Event.last)
    expect(Event.last).to be_preparing
    expect(Event.last.held_on).to eq Date.new(2026, 10, 18)
    expect(Event.last.slug).to eq "99"
  end

  it "開催日とスラッグが無いと作成できない" do
    sign_in(admin)

    expect {
      post admin_events_path, params: { event: { title: "TokyuRuby会議99", held_on: "", slug: "" } }
    }.not_to change(Event, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("開催日を入力してください", "スラッグを入力してください")
  end

  it "管理者は開催日とスラッグを更新できる" do
    sign_in(admin)

    patch admin_event_path(event), params: {
      event: { title: "TokyuRuby会議17", held_on: "2026-11-01", slug: "17" }
    }

    expect(response).to redirect_to(admin_event_path(event))
    event.reload
    expect(event.title).to eq "TokyuRuby会議17"
    expect(event.held_on).to eq Date.new(2026, 11, 1)
    expect(event.slug).to eq "17"
  end

  it "スラッグが重複すると更新できない" do
    create(:event, slug: "17")
    sign_in(admin)

    patch admin_event_path(event), params: {
      event: { title: event.title, held_on: "2026-10-18", slug: "17" }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(event.reload.slug).not_to eq "17"
  end

  it "タイトルが空なら作成できず、フォームに戻す" do
    sign_in(admin)

    post admin_events_path, params: { event: { title: "", held_on: "2026-10-18", slug: "99" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("タイトルを入力してください")
  end

  it "ステータス変更のボタンに確認ダイアログを付ける" do
    sign_in(admin)

    get admin_event_path(event)

    expect(response.body).to include('data-turbo-confirm="ステータスを変更します。よろしいですか？"')
  end

  it "管理者はステータスを変更できる" do
    sign_in(admin)

    patch admin_event_path(event), params: { event: { status: "open" } }

    expect(event.reload).to be_open
  end

  it "存在しないステータスには変更できない" do
    sign_in(admin)

    patch admin_event_path(event), params: { event: { status: "archived" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(event.reload).to be_preparing
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

    expect(response.body).to include("飯王（単品王）", "唐揚げ", "飯王（合算王）", "Ruby の話")
    expect(response.body).not_to include("LT王（単品王）")
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
