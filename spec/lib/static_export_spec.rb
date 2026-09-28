require "rails_helper"

RSpec.describe StaticExport do
  # 1x1 の PNG
  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==") }
  let(:out) { Rails.root.join("tmp/static_export_spec") }
  let(:event) { create(:event, status: :closed, title: "TokyuRuby会議99") }
  let(:food) { create(:category, category_name: :food) }

  before do
    food
    create(:category, category_name: :drink)
    create(:category, category_name: :talk)
  end

  after { FileUtils.rm_rf(out) }

  def page(path)
    out.join(path).read
  end

  it "結果公開済みのイベントだけを書き出す" do
    event
    create(:event, status: :counting, title: "集計中の会")

    described_class.new(out).run

    expect(page("index.html")).to include("TokyuRuby会議99", "events/#{event.id}/index.html")
    expect(page("index.html")).not_to include("集計中の会")
    expect(page("events/#{event.id}/index.html")).to include("food.html", "drink.html", "talk.html")
  end

  it "部門ごとのランキングとコメントを書き出す" do
    create(:vote, entry: create(:entry, event: event, category: food, title: "唐揚げ"), comment: "おいしかった")
    create(:talk_vote, talk: create(:talk, event: event, title: "Ruby の話"), comment: "よかった")

    described_class.new(out).run

    expect(page("events/#{event.id}/food.html")).to include("飯王（単品王）", "唐揚げ", "おいしかった")
    expect(page("events/#{event.id}/talk.html")).to include("LT王（単品王）", "Ruby の話", "よかった")
  end

  it "投票・ログイン・管理の導線と検証環境のバナーを含めない" do
    create(:entry, event: event, category: food)

    described_class.new(out).run

    html = page("events/#{event.id}/food.html")
    expect(html).not_to include("<form", "ログアウト", "/admin", "staging 環境です")
  end

  it "リンクとアセットを相対パスで参照する" do
    event

    described_class.new(out).run

    html = page("events/#{event.id}/food.html")
    expect(html).to include('href="../../assets/tailwind.css"', 'href="../../index.html"')
    expect(out.join("assets/tailwind.css")).to exist
    expect(out.join("icon.png")).to exist
  end

  it "エントリーの画像を書き出し、ページから参照する" do
    entry = create(:entry, event: event, category: food)
    entry.image.attach(io: StringIO.new(png), filename: "karaage.png", content_type: "image/png")

    described_class.new(out).run

    path = described_class.image_path(entry.image)
    expect(out.join(path).binread).to eq(png)
    expect(page("events/#{event.id}/food.html")).to include(%(src="../../#{path}"))
  end

  it "検証環境のときだけ検索避けのヘッダーを書き出す" do
    described_class.new(out).run
    expect(out.join("_headers")).not_to exist

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("APP_ENV_LABEL").and_return("staging")
    described_class.new(out).run
    expect(page("_headers")).to include("X-Robots-Tag: noindex, nofollow")
  end

  it "前回の書き出しを残さない" do
    FileUtils.mkdir_p(out)
    File.write(out.join("stale.html"), "old")

    described_class.new(out).run

    expect(out.join("stale.html")).not_to exist
  end
end
