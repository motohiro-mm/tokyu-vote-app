require "rails_helper"

RSpec.describe "管理者権限の解除", type: :request do
  let(:admin) { create(:user, :admin, name: "taro") }
  let!(:other_admin) { create(:user, :admin, name: "jiro") }

  it "管理者の一覧に管理者だけを出す" do
    create(:user, name: "hanako")
    sign_in(admin)

    get admin_administrators_path

    expect(response.body).to include("taro", "jiro")
    expect(response.body).not_to include("hanako")
  end

  it "ほかの管理者の権限を解除できる" do
    sign_in(admin)

    delete admin_administrator_path(other_admin)

    expect(other_admin.reload).not_to be_admin
    expect(response).to redirect_to admin_administrators_path
    expect(flash[:notice]).to eq "jiro の管理者権限を解除しました。"
  end

  it "解除された人は管理画面に入れなくなる" do
    sign_in(admin)
    delete admin_administrator_path(other_admin)
    sign_in(other_admin)

    get admin_events_path

    expect(response).to redirect_to root_path
  end

  it "自分の権限は解除できない" do
    sign_in(admin)

    delete admin_administrator_path(admin)

    expect(admin.reload).to be_admin
    expect(flash[:alert]).to eq "自分の管理者権限は解除できません。"
  end

  it "自分の行には解除ボタンを出さない" do
    sign_in(admin)

    get admin_administrators_path

    expect(response.body).to include(admin_administrator_path(other_admin))
    expect(response.body).not_to include(admin_administrator_path(admin))
  end

  it "管理者でない人は解除できない" do
    sign_in(create(:user))

    delete admin_administrator_path(other_admin)

    expect(other_admin.reload).to be_admin
    expect(response).to redirect_to root_path
  end
end
