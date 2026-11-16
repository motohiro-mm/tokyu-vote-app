# 管理者権限の解除。付与は GitHub の数値 ID で本人を確かめたいので、引き続き admin:grant タスクで行う
class Admin::AdministratorsController < Admin::BaseController
  def index
    @administrators = User.where(admin: true).order(:name)
  end

  def destroy
    user = User.where(admin: true).find(params[:id])

    # 自分を外すと、その場で管理画面から締め出されて戻せなくなるため止める。
    # 同時に互いを外して 0 人になるのは User#revoke_admin_by で防ぐ
    if user == current_user
      redirect_to admin_administrators_path, alert: "自分の管理者権限は解除できません。"
      return
    end

    if user.revoke_admin_by(current_user)
      redirect_to admin_administrators_path, notice: "#{user.name} の管理者権限を解除しました。"
    else
      redirect_to root_path, alert: "あなたの管理者権限はすでに解除されています。"
    end
  end
end
