require "rails_helper"

RSpec.describe "エントリー", type: :request do
  let(:event) { create(:event, status: :open) }
  let!(:food) { create(:category, category_name: :food) }
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "登録できる" do
    expect {
      post event_entries_path(event.slug, category: "food"), params: { entry: { title: "唐揚げ" } }
    }.to change(Entry, :count).by(1)
  end

  it "フォームから投稿した画像を表示できる" do
    image_path = Rails.root.join("app/assets/images/tokyu-rb-logo.png")
    image = fixture_file_upload(image_path, "image/png")
    post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ", image: image } }

    expect(response).to redirect_to event_entries_completions_path(event, category: "food")
    entry = event.entries.find_by!(title: "唐揚げ")
    get rails_blob_path(entry.image, only_path: true)
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body.b).to eq(image_path.binread)
  end

  it "登録すると登録完了画面へ送る" do
    post event_entries_path(event.slug, category: "food"), params: { entry: { title: "唐揚げ" } }

    expect(response).to redirect_to event_entries_completions_path(event.slug, category: "food")
    follow_redirect!
    expect(response.body).to include("登録が完了しました")
  end

  it "登録フォームの作品名ラベルに何の名前かを添える" do
    get new_event_entry_path(event.slug, category: "food")

    expect(response.body).to include("作品名（食べ物の名前）")
  end

  it "作品名が空なら登録できず、フォームに戻す" do
    create(:entry, event: event, category: food, user: user, title: "唐揚げ")

    post event_entries_path(event.slug, category: "food"), params: { entry: { title: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("作品名を入力してください").and include("唐揚げ")
  end

  it "部門選択にはLT王を並べない" do
    create(:category, category_name: :talk)

    get event_entries_categories_path(event.slug)

    expect(response.body).to include(new_event_entry_path(event.slug, category: "food"))
    expect(response.body).not_to include(new_event_entry_path(event.slug, category: "talk"))
  end

  it "登録済みの作品を出す" do
    create(:entry, event: event, category: food, user: user, title: "唐揚げ")

    get new_event_entry_path(event.slug, category: "food")

    expect(response.body).to include("登録済みの作品").and include("唐揚げ")
  end

  it "受付前は登録できない" do
    event.preparing!

    expect {
      post event_entries_path(event.slug, category: "food"), params: { entry: { title: "唐揚げ" } }
    }.not_to change(Entry, :count)
  end

  it "LT王の部門は扱わない" do
    create(:category, category_name: :talk)

    get new_event_entry_path(event.slug, category: "talk")

    expect(response).to have_http_status(:not_found)
  end

  it "未知の部門名は見つからない" do
    get new_event_entry_path(event.slug, category: "beer")

    expect(response).to have_http_status(:not_found)
  end
end

RSpec.describe "エントリー画像の直接アップロード", type: :request do
  let(:contents) { "test" }
  let(:blob_attributes) do
    { filename: "test.txt", byte_size: contents.bytesize,
      checksum: Digest::MD5.base64digest(contents), content_type: "text/plain" }
  end

  it "アップロード用のURLを発行しない" do
    expect {
      post rails_direct_uploads_path, params: { blob: blob_attributes }, as: :json
    }.not_to change(ActiveStorage::Blob, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "発行済みのURLを使ったファイルの保存も拒否する" do
    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_attributes)
    url = ActiveStorage::Current.set(url_options: { host: "www.example.com" }) do
      blob.service_url_for_direct_upload
    end

    put url, params: contents, headers: blob.service_headers_for_direct_upload

    expect(response).to have_http_status(:not_found)
    expect(blob.service.exist?(blob.key)).to be(false)
  end
end
