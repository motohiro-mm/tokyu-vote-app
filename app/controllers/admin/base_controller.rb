# 管理コントローラを増やすたびに認可を書き足さずに済むよう、ここに集約する。
class Admin::BaseController < ApplicationController
  before_action :require_admin

  layout "application"
end
