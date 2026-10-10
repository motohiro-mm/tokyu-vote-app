require "rails_helper"

RSpec.describe "LT候補の管理", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }

  before { sign_in(admin) }

  it "イベントの管理画面にLTの一覧を出す" do
    create(:talk, event: event, title: "Ruby の話")
    create(:talk, event: event, title: "欠席の話", status: :canceled)

    get admin_event_path(event)

    expect(response.body).to include("Ruby の話", "欠席の話", "キャンセル", new_admin_event_talk_path(event))
  end

  it "管理者はLTを登録できる" do
    expect {
      post admin_event_talks_path(event), params: { talk: { user_name: "とうだんしゃ", title: "Ruby の話" } }
    }.to change(event.talks, :count).by(1)
    expect(response).to redirect_to admin_event_path(event)
  end

  it "タイトルが空なら登録できず、フォームに戻す" do
    post admin_event_talks_path(event), params: { talk: { user_name: "とうだんしゃ", title: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("LTタイトルを入力してください")
  end

  it "準備中のあいだはキャンセルにできる" do
    talk = create(:talk, event: event)

    patch admin_event_talk_path(event, talk), params: { talk: { status: "canceled" } }

    expect(talk.reload).to be_canceled
  end

  it "投票開始後はキャンセルにできない" do
    event.open!
    talk = create(:talk, event: event)

    patch admin_event_talk_path(event, talk), params: { talk: { status: "canceled" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(talk.reload).to be_scheduled
  end

  it "別のイベントのLTは編集できない" do
    talk = create(:talk, event: create(:event))

    get edit_admin_event_talk_path(event, talk)

    expect(response).to have_http_status(:not_found)
  end

  it "一般ユーザーは登録できない" do
    sign_in(create(:user))

    post admin_event_talks_path(event), params: { talk: { user_name: "とうだんしゃ", title: "Ruby の話" } }

    expect(response).to redirect_to root_path
    expect(event.talks.count).to eq 0
  end

  describe "CSV 一括登録" do
    def upload(text)
      file = Rack::Test::UploadedFile.new(StringIO.new(text), "text/csv", original_filename: "talks.csv")
      post admin_event_talk_imports_path(event), params: { file: file }
    end

    it "CSV の行をまとめて登録する" do
      expect {
        upload("登壇者名,LTタイトル\nとうだんしゃ1,Ruby の話\nとうだんしゃ2,SQLite の話\n")
      }.to change(event.talks, :count).by(2)
      expect(flash[:notice]).to eq "2 件のLTを登録しました。"
    end

    it "不正な行があれば 1 件も登録しない" do
      expect {
        upload("登壇者名,LTタイトル\nとうだんしゃ1,Ruby の話\nとうだんしゃ2,\n")
      }.not_to change(Talk, :count)
      expect(flash[:alert]).to include("3 行目")
    end

    it "ファイルが無ければ知らせる" do
      post admin_event_talk_imports_path(event)

      expect(flash[:alert]).to eq "CSV ファイルを選んでください。"
    end
  end
end
