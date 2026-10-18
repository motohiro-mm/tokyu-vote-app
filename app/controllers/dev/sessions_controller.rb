# GitHub を設定していない手元の環境で、ユーザーを切り替えて画面を確認する。
# routes.rb で development と test のときだけ有効にしている。
class Dev::SessionsController < ApplicationController
  skip_before_action :require_login

  def create
    log_in(User.find(params[:user_id]))
    redirect_to root_path
  end
end
