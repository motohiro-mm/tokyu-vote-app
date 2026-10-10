# GitHub OAuth を入れるまで、画面を確認するためにユーザーを切り替える。
# routes.rb で development のときだけ有効にしている。
class Dev::SessionsController < ApplicationController
  skip_before_action :require_login

  def create
    log_in(User.find(params[:user_id]))
    redirect_to root_path
  end
end
