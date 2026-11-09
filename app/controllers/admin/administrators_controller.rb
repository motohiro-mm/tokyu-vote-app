# 管理者権限の解除。付与は GitHub の数値 ID で本人を確かめたいので、引き続き admin:grant タスクで行う
class Admin::AdministratorsController < Admin::BaseController
  def index
    @administrators = User.where(admin: true).order(:name)
  end

  def destroy
    user = User.where(admin: true).find(params[:id])

    # 自分を外すと、その場で管理画面から締め出されて戻せなくなるため止める。
    # 自分以外しか外せないので、管理者が 0 人になることもない
    if user == current_user
      redirect_to admin_administrators_path, alert: "自分の管理者権限は解除できません。"
      return
    end

    user.update!(admin: false)
    redirect_to admin_administrators_path, notice: "#{user.name} の管理者権限を解除しました。"
  end
end
