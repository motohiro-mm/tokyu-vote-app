require "rails_helper"

RSpec.describe Ranking do
  let(:event) { create(:event, status: :open) }
  let(:food) { create(:category, category_name: :food) }

  # 1ユーザーが同じ部門に投じられるのは3票までなので、票数の分だけ投票者を作る
  def vote_for(entry, count)
    count.times { create(:vote, user: create(:user), entry: entry) }
  end

  def vote_for_talk(talk, count)
    count.times { create(:talk_vote, user: create(:user), talk: talk) }
  end

  describe ".singles" do
    it "エントリー単位の得票数を多い順に3位まで返す" do
      first = create(:entry, event: event, category: food, title: "唐揚げ")
      second = create(:entry, event: event, category: food, title: "餃子")
      third = create(:entry, event: event, category: food, title: "肉じゃが")
      create(:entry, event: event, category: food, title: "おにぎり")
      vote_for(first, 3)
      vote_for(second, 2)
      vote_for(third, 1)

      rows = described_class.singles(event, food)

      expect(rows.map(&:title)).to eq [ "唐揚げ", "餃子", "肉じゃが" ]
      expect(rows.map(&:rank)).to eq [ 1, 2, 3 ]
      expect(rows.map(&:vote_count)).to eq [ 3, 2, 1 ]
    end

    it "同票は同順位にし、次の順位をその分だけ飛ばす" do
      vote_for(create(:entry, event: event, category: food), 2)
      vote_for(create(:entry, event: event, category: food), 2)
      vote_for(create(:entry, event: event, category: food), 1)

      expect(described_class.singles(event, food).map(&:rank)).to eq [ 1, 1, 3 ]
    end

    it "3位が同票で並んだときは4件目以降も載せる" do
      vote_for(create(:entry, event: event, category: food), 3)
      vote_for(create(:entry, event: event, category: food), 2)
      vote_for(create(:entry, event: event, category: food), 1)
      vote_for(create(:entry, event: event, category: food), 1)

      expect(described_class.singles(event, food).map(&:rank)).to eq [ 1, 2, 3, 3 ]
    end

    it "4位以下は載せない" do
      4.downto(1) { |count| vote_for(create(:entry, event: event, category: food), count) }

      expect(described_class.singles(event, food).map(&:vote_count)).to eq [ 4, 3, 2 ]
    end

    it "1票も入っていないエントリーは載せない" do
      create(:entry, event: event, category: food)

      expect(described_class.singles(event, food)).to be_empty
    end

    it "他の部門・他のイベントの票は数えない" do
      drink = create(:category, category_name: :drink)
      entry = create(:entry, event: event, category: food)
      vote_for(entry, 1)
      vote_for(create(:entry, event: event, category: drink), 3)
      vote_for(create(:entry, event: create(:event), category: food), 3)

      rows = described_class.singles(event, food)

      expect(rows.map(&:vote_count)).to eq [ 1 ]
      expect(rows.first.name).to eq entry.user.name
    end
  end

  describe ".totals" do
    it "同じ人が同じ部門に出したエントリーの得票数を合算する" do
      user = create(:user, name: "もとひろ")
      vote_for(create(:entry, user: user, event: event, category: food), 2)
      vote_for(create(:entry, user: user, event: event, category: food), 2)
      vote_for(create(:entry, event: event, category: food), 3)

      rows = described_class.totals(event, food)

      expect(rows.map(&:name).first).to eq "もとひろ"
      expect(rows.map(&:vote_count)).to eq [ 4, 3 ]
    end

    it "部門をまたいでは合算しない" do
      drink = create(:category, category_name: :drink)
      user = create(:user)
      vote_for(create(:entry, user: user, event: event, category: food), 2)
      vote_for(create(:entry, user: user, event: event, category: drink), 3)

      expect(described_class.totals(event, food).map(&:vote_count)).to eq [ 2 ]
    end
  end

  describe ".talks" do
    it "LT単位の得票数を多い順に返す" do
      talk = create(:talk, event: event, user_name: "登壇者A", title: "Ruby の話")
      vote_for_talk(talk, 2)
      vote_for_talk(create(:talk, event: event), 1)

      rows = described_class.talks(event)

      expect(rows.map(&:rank)).to eq [ 1, 2 ]
      expect(rows.first).to have_attributes(name: "登壇者A", title: "Ruby の話", vote_count: 2)
    end

    it "他のイベントの票は数えない" do
      vote_for_talk(create(:talk, event: create(:event)), 2)

      expect(described_class.talks(event)).to be_empty
    end
  end
end
