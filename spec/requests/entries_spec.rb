require "rails_helper"

RSpec.describe "エントリー", type: :request do
  let(:event) { create(:event, status: :open) }
  let!(:food) { create(:category, category_name: :food) }
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "登録できる" do
    expect {
      post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }
    }.to change(Entry, :count).by(1)
  end

  it "画像5枚を登録でき、投票一覧には先頭の画像を、詳細と結果には全画像を表示する" do
    png = Rails.root.join("public/icon.png")
    names = %w[entry.heic second.png third.png fourth.png fifth.png]
    photos = [ fixture_file_upload(names.first, "application/octet-stream") ]
    photos.concat(names.drop(1).map { |name| Rack::Test::UploadedFile.new(png, "image/png", true, original_filename: name) })
    post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ", image: photos } }
    expect(response).to redirect_to(event_entries_completions_path(event, category: "food"))
    entry = event.entries.find_by!(title: "唐揚げ")

    get event_entries_path(event, category: "food")
    expect(response.body).to include("/entry.heic")
    expect(Nokogiri::HTML(response.body).css("main li img").size).to eq(1)

    get event_entry_path(event, entry, category: "food")
    images = Nokogiri::HTML(response.body).css('img[alt="唐揚げ"]')
    expect(images.map { |image| File.basename(image["src"]) }).to eq(names)

    get images.first["src"]
    follow_redirect!
    expect(response.media_type).to eq("image/jpeg")
    expect(response.body.b).to start_with("\xFF\xD8\xFF".b)

    create(:vote, entry: entry, comment: "おいしかった")
    event.closed!
    get event_results_path(event, category: "food")
    expect(response.body).to include(*names.map { |name| "/#{name}" })
  end

  it "登録すると登録完了画面へ送る" do
    post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }

    expect(response).to redirect_to event_entries_completions_path(event, category: "food")
    follow_redirect!
    expect(response.body).to include("登録が完了しました")
  end

  it "登録フォームの作品名ラベルに何の名前かを添える" do
    get new_event_entry_path(event, category: "food")

    expect(response.body).to include("作品名（食べ物の名前）", "1枚5MBまで、最大5枚")
    input = Nokogiri::HTML(response.body).at_css('input[type="file"][name="entry[image][]"][multiple]')
    expect(input["accept"]).to include(".heic", ".heif")
  end

  it "作品名が空なら登録できず、フォームに戻す" do
    create(:entry, event: event, category: food, user: user, title: "唐揚げ")

    post event_entries_path(event, category: "food"), params: { entry: { title: "" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("作品名を入力してください").and include("唐揚げ")
  end

  it "部門選択にはLT王を並べない" do
    create(:category, category_name: :talk)

    get event_entries_categories_path(event)

    expect(response.body).to include(new_event_entry_path(event, category: "food"))
    expect(response.body).not_to include(new_event_entry_path(event, category: "talk"))
  end

  it "登録済みの作品を出す" do
    create(:entry, event: event, category: food, user: user, title: "唐揚げ")

    get new_event_entry_path(event, category: "food")

    expect(response.body).to include("登録済みの作品").and include("唐揚げ")
  end

  it "受付前は登録できない" do
    event.preparing!

    expect {
      post event_entries_path(event, category: "food"), params: { entry: { title: "唐揚げ" } }
    }.not_to change(Entry, :count)
  end

  it "LT王の部門は扱わない" do
    create(:category, category_name: :talk)

    get new_event_entry_path(event, category: "talk")

    expect(response).to have_http_status(:not_found)
  end

  it "未知の部門名は見つからない" do
    get new_event_entry_path(event, category: "beer")

    expect(response).to have_http_status(:not_found)
  end
end
