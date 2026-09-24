require "rails_helper"

RSpec.describe "イベント管理", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }

  it "管理者はステータスを変更できる" do
    sign_in(admin)

    patch admin_event_path(event), params: { event: { status: "open" } }

    expect(event.reload).to be_open
  end

  it "一般ユーザーは管理画面に入れない" do
    sign_in(create(:user))

    get admin_events_path

    expect(response).to redirect_to root_path
  end

  it "未ログインでは管理画面に入れない" do
    get admin_events_path

    expect(response).to redirect_to login_path
  end
end
