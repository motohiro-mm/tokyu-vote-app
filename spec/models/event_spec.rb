require "rails_helper"

RSpec.describe Event do
  it "削除するとエントリーとLT候補も消える" do
    event = create(:event)
    create(:entry, event: event)
    create(:talk, event: event)

    expect { event.destroy }.to change(Entry, :count).by(-1).and change(Talk, :count).by(-1)
  end

  it "ステータスは4種類" do
    expect(described_class.statuses.keys).to eq %w[preparing open counting closed]
  end

  it "集計中と結果公開のときだけ集計を始めたとみなす" do
    started = described_class.statuses.keys.select { |status| build(:event, status: status).counting_started? }

    expect(started).to eq %w[counting closed]
  end
end
