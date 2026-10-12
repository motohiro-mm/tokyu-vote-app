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
end
