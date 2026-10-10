class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :failure ]

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

  def destroy
    reset_session
    redirect_to login_path, notice: "ログアウトしました。"
  end
end
