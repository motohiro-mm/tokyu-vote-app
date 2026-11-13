require "rails_helper"

RSpec.describe "LT候補の管理", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }

  before { sign_in(admin) }

  it "イベントの管理画面にLTの一覧を出す" do
    create(:talk, event: event, title: "Ruby の話")
    create(:talk, event: event, title: "欠席の話", status: :canceled)

    get admin_event_path(event)

    expect(response.body).to include("LTの一覧", "Ruby の話", "欠席の話", "キャンセル", new_admin_event_talk_path(event))
  end

  it "公開中のあいだはまだLTを登録できる" do
    event.open!

    expect {
      post admin_event_talks_path(event), params: { talk: { user_name: "とうだんしゃ", title: "Ruby の話" } }
    }.to change(event.talks, :count).by(1)
  end

  it "集計中になるとLTを登録できず、管理画面にも登録の導線を出さない" do
    event.counting!

    get admin_event_path(event)
    expect(response.body).not_to include(new_admin_event_talk_path(event))

    get new_admin_event_talk_path(event)
    expect(response).to redirect_to admin_event_path(event)

    expect {
      post admin_event_talks_path(event), params: { talk: { user_name: "とうだんしゃ", title: "Ruby の話" } }
    }.not_to change(Talk, :count)
    expect(flash[:alert]).to eq "LTの登録は準備中・公開中のあいだだけできます。"
  end

  it "管理者はLTを登録できる" do
    expect {
      post admin_event_talks_path(event), params: { talk: { user_name: "とうだんしゃ", title: "Ruby の話" } }
    }.to change(event.talks, :count).by(1)
    expect(response).to redirect_to admin_event_path(event)
  end

  it "説明付きでも空欄でも登録できる" do
    post admin_event_talks_path(event), params: { talk: { user_name: "登壇者", title: "説明あり", description: "紹介文" } }
    post admin_event_talks_path(event), params: { talk: { user_name: "登壇者", title: "説明なし", description: "" } }

    expect(event.talks.find_by!(title: "説明あり").description).to eq "紹介文"
    expect(event.talks.find_by!(title: "説明なし").description).to be_blank
  end

  it "発表資料URL付きでも空欄でも登録できる" do
    post admin_event_talks_path(event), params: { talk: { user_name: "登壇者", title: "URLあり", slide_url: " https://example.com " } }
    post admin_event_talks_path(event), params: { talk: { user_name: "登壇者", title: "URLなし", slide_url: "" } }

    expect(event.talks.find_by!(title: "URLあり").slide_url).to eq "https://example.com"
    expect(event.talks.find_by!(title: "URLなし").slide_url).to be_nil
  end

  it "不正な発表資料URLは登録・更新できずフォームに戻す" do
    post admin_event_talks_path(event), params: { talk: { user_name: "登壇者", title: "Ruby", slide_url: "javascript:alert(1)" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("発表資料URLは http または https の URL で入力してください")
    expect(event.talks.count).to eq 0

    talk = create(:talk, event: event, slide_url: "https://example.com")
    patch admin_event_talk_path(event, talk), params: { talk: { slide_url: "ftp://example.com" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(talk.reload.slide_url).to eq "https://example.com"
  end

  it "タイトルが空なら登録できず、フォームに戻す" do
    post admin_event_talks_path(event), params: { talk: { user_name: "とうだんしゃ", title: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("LTタイトルを入力してください")
  end

  it "編集画面を出し、登壇者名とタイトルを変えられる" do
    talk = create(:talk, event: event, title: "Ruby の話")

    get edit_admin_event_talk_path(event, talk)
    expect(response.body).to include("Ruby の話")

    patch admin_event_talk_path(event, talk), params: { talk: { user_name: "とうだんしゃ", title: "Rails の話" } }

    expect(response).to redirect_to admin_event_path(event)
    expect(talk.reload).to have_attributes(user_name: "とうだんしゃ", title: "Rails の話")
  end

  it "投票開始後も説明を更新できる" do
    event.open!
    talk = create(:talk, event: event)

    patch admin_event_talk_path(event, talk), params: { talk: { description: "更新した説明", slide_url: "https://example.com/slides" } }

    expect(response).to redirect_to admin_event_path(event)
    expect(talk.reload).to have_attributes(description: "更新した説明", slide_url: "https://example.com/slides")
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

    it "集計中になると CSV でも登録できない" do
      event.counting!

      expect {
        upload("登壇者名,LTタイトル\nとうだんしゃ1,Ruby の話\n")
      }.not_to change(Talk, :count)
      expect(flash[:alert]).to eq "LTの登録は準備中・公開中のあいだだけできます。"
    end

    it "ファイルが無ければ知らせる" do
      post admin_event_talk_imports_path(event)

      expect(flash[:alert]).to eq "CSV ファイルを選んでください。"
    end

    it "ファイルでない値が送られても 500 にせず知らせる" do
      post admin_event_talk_imports_path(event), params: { file: "abc" }

      expect(response).to redirect_to admin_event_path(event)
      expect(flash[:alert]).to eq "CSV ファイルを選んでください。"
    end

    it "上限を超える大きさの CSV は読まずに断る" do
      text = "登壇者名,LTタイトル\n" + ("とうだんしゃ,Ruby の話\n" * (Admin::TalkImportsController::CSV_MAX_SIZE / 20))

      expect { upload(text) }.not_to change(Talk, :count)
      expect(flash[:alert]).to eq "CSV ファイルが大きすぎます（1MB まで）。"
    end
  end
end
