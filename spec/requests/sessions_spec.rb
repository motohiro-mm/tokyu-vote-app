require "rails_helper"

RSpec.describe "ログイン", type: :request do
  def github_login(uid: "12345", nickname: "alice")
    mock_github_auth(uid: uid, nickname: nickname)
    post "/auth/github"
    follow_redirect!
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
