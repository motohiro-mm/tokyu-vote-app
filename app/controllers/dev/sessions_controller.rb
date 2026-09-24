# GitHub OAuth を入れるまで、画面を確認するためにユーザーを切り替える。
# routes.rb で development のときだけ有効にしている。
class Dev::SessionsController < ApplicationController
  skip_before_action :require_login

  def create
    reset_session
    session[:user_id] = User.find(params[:user_id]).id
    redirect_to root_path
  end
end
