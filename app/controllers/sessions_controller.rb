class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :failure ]

  helper_method :github_configured?

  def new
    # GitHub を設定していない development では開発用ログインで画面を確認する
    @users = User.order(:id) if Rails.env.development?
  end

  # GitHub から戻ってきたとき。OmniAuth が検証済みの auth hash を env に入れている
  def create
    user = User.find_or_create_from_auth_hash!(request.env["omniauth.auth"])
    log_in(user)
    redirect_to root_path, notice: "ログインしました。"
  end

  # GitHub 側で拒否されたときや、認可コードの検証に失敗したとき
  def failure
    redirect_to login_path, alert: "GitHub でのログインに失敗しました。もう一度お試しください。"
  end

  # Cookie が盗まれていた場合に備え、サーバー側のトークンも消して以前の Cookie を無効にする。
  # 全端末からのログアウトになるが、このアプリの用途では問題にならない
  def destroy
    current_user&.update!(session_digest: nil)
    reset_session
    redirect_to login_path, notice: "ログアウトしました。"
  end

  private

  # クライアント ID が無いまま GitHub へ飛ばすと、GitHub 側で 404 になる。
  # 未設定の環境ではボタンを出さず、設定が要ることを画面で知らせる
  def github_configured?
    ENV["GITHUB_CLIENT_ID"].present? && ENV["GITHUB_CLIENT_SECRET"].present?
  end
end
