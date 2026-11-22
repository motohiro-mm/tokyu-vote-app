require "rails_helper"

RSpec.describe CategoryResult do
  let(:event) { create(:event, status: :closed) }
  let(:food) { create(:category, category_name: :food) }
  let(:talk_category) { create(:category, category_name: :talk) }

  it "飯王・酒王は単品王と合算王を出す" do
    titles = described_class.new(event, food).rankings.map(&:first)

    expect(titles).to eq([ "飯王（単品王）", "飯王（合算王）" ])
  end

  it "LT王は合算王を出さず、見出しも部門名だけにする" do
    titles = described_class.new(event, talk_category).rankings.map(&:first)

    expect(titles).to eq([ "LT王" ])
  end

  it "エントリーごとに空でないコメントをまとめ、コメントの無いエントリーは出さない" do
    entry = create(:entry, event: event, category: food, title: "唐揚げ")
    create(:entry, event: event, category: food, title: "ポテトサラダ")
    create(:vote, entry: entry, comment: "おいしかった")
    create(:vote, entry: entry, comment: "  ")
    create(:vote, entry: entry, comment: nil)
    create(:vote, entry: entry, comment: "また食べたい")

    targets = described_class.new(event, food).targets

    expect(targets.map(&:title)).to eq([ "唐揚げ" ])
    expect(targets.first.comments).to eq([ "おいしかった", "また食べたい" ])
  end

  it "写真は1枚目だけを添える" do
    entry = create(:entry, event: event, category: food)
    entry.images.attach([ "first.jpg", "second.jpg" ].map { |name| { io: StringIO.new("dummy"), filename: name, content_type: "image/jpeg" } })
    create(:vote, entry: entry, comment: "おいしかった")

    image = described_class.new(event, food).targets.first.image

    expect(image.thumbnail.blob.filename.to_s).to eq "first.jpg"
    expect(image.display.blob.filename.to_s).to eq "first.jpg"
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

  describe "#placements" do
    it "単品王はその作品の順位を、合算王は持ち込んだ人の順位を返す" do
      user = create(:user)
      entry = create(:entry, event: event, category: food, user: user)
      other = create(:entry, event: event, category: food, user: user)
      rival = create(:entry, event: event, category: food)
      create_list(:vote, 2, entry: entry)
      create_list(:vote, 2, entry: other)
      create_list(:vote, 3, entry: rival)

      placements = described_class.new(event, food).placements(entry.id).to_h { |title, row| [ title, [ row.rank, row.vote_count ] ] }

      expect(placements).to eq("飯王（単品王）" => [ 2, 2 ], "飯王（合算王）" => [ 1, 4 ])
    end

    it "票の無い作品は空にする" do
      entry = create(:entry, event: event, category: food)

      expect(described_class.new(event, food).placements(entry.id)).to be_empty
    end
  end

  describe "#comments_for" do
    it "その作品への空でないコメントだけを返す" do
      entry = create(:entry, event: event, category: food)
      create(:vote, entry: entry, comment: "おいしかった")
      create(:vote, entry: entry, comment: "")
      create(:vote, entry: create(:entry, event: event, category: food), comment: "ほかの作品")

      expect(described_class.new(event, food).comments_for(entry.id)).to eq [ "おいしかった" ]
    end
  end
end
