require "rails_helper"

RSpec.describe CategoryResult do
  let(:event) { create(:event, status: :closed) }
  let(:food) { create(:category, category_name: :food) }
  let(:talk_category) { create(:category, category_name: :talk) }

  it "飯王・酒王は単品王と合算王を出す" do
    titles = described_class.new(event, food).rankings.map(&:first)

    expect(titles).to eq([ "飯王（単品王）", "飯王（合算王）" ])
  end

  it "LT王は単品王だけを出す" do
    titles = described_class.new(event, talk_category).rankings.map(&:first)

    expect(titles).to eq([ "LT王（単品王）" ])
  end

  it "エントリーごとに空でないコメントをまとめる" do
    entry = create(:entry, event: event, category: food, title: "唐揚げ")
    create(:entry, event: event, category: food, title: "ポテトサラダ")
    create(:vote, entry: entry, comment: "おいしかった")
    create(:vote, entry: entry, comment: "  ")
    create(:vote, entry: entry, comment: nil)
    create(:vote, entry: entry, comment: "また食べたい")

    targets = described_class.new(event, food).targets

    expect(targets.map(&:title)).to eq([ "唐揚げ", "ポテトサラダ" ])
    expect(targets.first.comments).to eq([ "おいしかった", "また食べたい" ])
    expect(targets.second.comments).to be_empty
  end

  it "ほかの部門やイベントのエントリーを混ぜない" do
    drink = create(:category, category_name: :drink)
    create(:entry, event: event, category: drink)
    create(:entry, event: create(:event), category: food)

    expect(described_class.new(event, food).targets).to be_empty
  end

  it "LT王はキャンセルされたLTを出さない" do
    talk = create(:talk, event: event, title: "Ruby の話")
    create(:talk, event: event, status: :canceled)
    create(:talk_vote, talk: talk, comment: "よかった")

    targets = described_class.new(event, talk_category).targets

    expect(targets.map(&:title)).to eq([ "Ruby の話" ])
    expect(targets.first.comments).to eq([ "よかった" ])
  end
end
