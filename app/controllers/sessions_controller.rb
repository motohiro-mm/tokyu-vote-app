class SessionsController < ApplicationController
  skip_before_action :require_login, only: :new

  # GitHub OAuth はまだ繋いでいないため、この画面は development の
  # ユーザー切り替えだけが動く
  def new
    @users = User.order(:id) if Rails.env.development?
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "ログアウトしました。"
  end
end
