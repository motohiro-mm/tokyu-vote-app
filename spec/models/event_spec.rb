require "rails_helper"

RSpec.describe Event do
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

  it "スラッグは英数字とハイフンだけで、予約パスは使えない" do
    event = build(:event, slug: "tokyu-17")
    expect(event).to be_valid

    event.slug = "第17回"
    expect(event).not_to be_valid
    expect(event.errors.of_kind?(:slug, :invalid)).to be true

    event.slug = "login"
    expect(event).not_to be_valid
    expect(event.errors.of_kind?(:slug, :reserved)).to be true
  end
end
