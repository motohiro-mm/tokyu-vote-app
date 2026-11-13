require "rails_helper"

RSpec.describe Event do
  describe ".current" do
    it "受付中・集計中を他の状態より優先し、その中で作成日時とIDの降順に選ぶ" do
      time = 1.day.ago
      create(:event, status: :open, created_at: time - 1.second)
      create(:event, status: :open, created_at: time)
      latest = create(:event, status: :counting, created_at: time)
      create(:event, status: :preparing)
      create(:event, status: :closed)
      create(:event, status: :finished)

      expect(described_class.current).to eq latest
    end

    it "受付中・集計中がなければ終了済みを除き、作成日時とIDの降順に選ぶ" do
      time = 1.day.ago
      create(:event, status: :preparing, created_at: time - 1.second)
      create(:event, status: :preparing, created_at: time)
      latest = create(:event, status: :closed, created_at: time)
      create(:event, status: :finished)

      expect(described_class.current).to eq latest
    end

    it "終了済みしかない場合とイベントがない場合はnilを返す" do
      finished = create(:event, status: :finished)
      expect(described_class.current).to be_nil

      finished.destroy!
      expect(described_class.current).to be_nil
    end
  end

  it "削除するとエントリーとLT候補も消える" do
    event = create(:event)
    create(:entry, event: event)
    create(:talk, event: event)

    expect { event.destroy }.to change(Entry, :count).by(-1).and change(Talk, :count).by(-1)
  end

  it "ステータスは5種類" do
    expect(described_class.statuses.keys).to eq %w[preparing open counting closed finished]
  end

  it "集計中・結果公開・終了のときだけ集計を始めたとみなす" do
    started = described_class.statuses.keys.select { |status| build(:event, status: status).counting_started? }

    expect(started).to eq %w[counting closed finished]
  end

  it "結果公開と終了のときだけ結果を公開済みとみなす" do
    published = described_class.statuses.keys.select { |status| build(:event, status: status).results_published? }

    expect(published).to eq %w[closed finished]
  end

  it "準備中と公開中のあいだだけLTを登録できる" do
    accepting = described_class.statuses.keys.select { |status| build(:event, status: status).accepting_talks? }

    expect(accepting).to eq %w[preparing open]
  end

  it "スラッグは重複できない" do
    create(:event, slug: "17")
    duplicate = build(:event, slug: "17")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.of_kind?(:slug, :taken)).to be true
  end

  it "スラッグのユニーク索引で同じ値は保存できない" do
    create(:event, slug: "17")
    other = create(:event)

    expect { other.update_columns(slug: "17") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "保存済みのスラッグは変更も削除もできない" do
    event = create(:event, slug: "17")

    [ "18", "", nil ].each do |slug|
      expect(event.update(slug: slug)).to be false
      expect(event.errors.of_kind?(:slug, :immutable)).to be true
      expect(event.reload.slug).to eq "17"
    end
  end

  it "未設定のスラッグを設定でき、設定後も他の項目を更新できる" do
    event = create(:event)
    event.update_columns(slug: nil)

    expect(event.update(slug: "17")).to be true
    expect(event.update(slug: "17", title: "新しいタイトル", held_on: Date.new(2026, 11, 1))).to be true
    expect(event.reload.attributes.values_at("slug", "title", "held_on")).to eq [ "17", "新しいタイトル", Date.new(2026, 11, 1) ]
  end

  it "スラッグが空の既存行は複数あってもステータスを変更できる" do
    first = create(:event)
    second = create(:event)
    first.update_columns(slug: nil, held_on: nil)
    second.update_columns(slug: nil, held_on: nil)

    expect(first.update(status: :open)).to be true
    expect(second.update(status: :counting)).to be true
  end

  it "新規では開催日とスラッグが必須" do
    event = build(:event, slug: nil, held_on: nil)

    expect(event).not_to be_valid
    expect(event.errors.of_kind?(:slug, :blank)).to be true
    expect(event.errors.of_kind?(:held_on, :blank)).to be true
  end

  it "管理画面の更新では開催日とスラッグが必須" do
    event = create(:event)
    event.assign_attributes(slug: nil, held_on: nil)

    expect(event.valid?(:edition)).to be false
    expect(event.errors.of_kind?(:slug, :blank)).to be true
    expect(event.errors.of_kind?(:held_on, :blank)).to be true
  end

  it "スラッグは英数字とハイフンだけを使う" do
    event = build(:event, slug: "tokyu-17")
    expect(event).to be_valid

    event.slug = "第17回"
    expect(event).not_to be_valid
    expect(event.errors.of_kind?(:slug, :invalid)).to be true

    event.slug = "login"
    expect(event).to be_valid
  end
end
