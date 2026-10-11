require "rails_helper"

RSpec.describe "ログイン", type: :request do
  def github_login(uid: "12345", nickname: "alice")
    mock_github_auth(uid: uid, nickname: nickname)
    post "/auth/github"
    follow_redirect!
  end

  it "GitHub を設定していればログイン画面にボタンを出す" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GITHUB_CLIENT_ID").and_return("id")
    allow(ENV).to receive(:[]).with("GITHUB_CLIENT_SECRET").and_return("secret")

    get login_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("GitHub でログインする")
  end

  it "GitHub を設定していなければボタンを出さず、設定が要ることを知らせる" do
    get login_path

    expect(response.body).not_to include("GitHub でログインする")
    expect(response.body).to include("GitHub ログインは設定されていません")
  end

  it "開発用ログインでもログインできる" do
    event = create(:event, status: :open)

    post dev_sessions_path(user_id: create(:user).id)
    get event_path(event)

    expect(response).to have_http_status(:ok)
  end

  it "検証環境では赤いバナーを出す" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("APP_ENV_LABEL").and_return("staging")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("STAGING_BASIC_AUTH_PASSWORD").and_return("secret")

    get login_path, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("staging", "secret") }

    expect(response.body).to include("staging 環境です。ここでの投票は集計されません。")
  end

  it "GitHub で初めてログインするとユーザーを作り、イベント画面へ送る" do
    expect { github_login }.to change(User, :count).by(1)

    expect(User.last).to have_attributes(provider: "github", uid: "12345", name: "alice")
    expect(response).to redirect_to root_path
    follow_redirect!
    expect(response.body).to include("alice")
  end

  it "2 回目のログインではユーザーを作らず、変わった nickname を反映する" do
    user = create(:user, provider: "github", uid: "12345", name: "alice")

    expect { github_login(nickname: "alice-new") }.not_to change(User, :count)
    expect(user.reload.name).to eq "alice-new"
  end

  it "GitHub 側で失敗するとログイン画面に戻す" do
    OmniAuth.config.mock_auth[:github] = :invalid_credentials

    post "/auth/github"
    follow_redirect! # テストモードではまず callback へ飛び、そこで失敗して /auth/failure へ送られる
    follow_redirect!

    expect(response).to redirect_to login_path
    follow_redirect!
    expect(response.body).to include("GitHub でのログインに失敗しました")
  end

  it "GET では認証を始められない" do
    get "/auth/github"

    expect(response).to have_http_status(:not_found)
  end

  it "ログアウトするとログイン画面に戻り、再ログインが要る" do
    github_login

    delete logout_path
    get root_path

    expect(response).to redirect_to login_path
  end

  it "サーバー側でトークンを消すと、セッションが残っていてもログアウト扱いになる" do
    github_login
    User.last.update!(session_digest: nil)

    get root_path

    expect(response).to redirect_to login_path
  end
end
