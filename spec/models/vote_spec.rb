require "rails_helper"

RSpec.describe Vote do
  let(:event) { create(:event, status: :open) }
  let(:category) { create(:category, category_name: :food) }
  let(:user) { create(:user) }

  def entry_in(target_category = category)
    create(:entry, event: event, category: target_category)
  end

  # 1ユーザーが同じ部門に投じられるのは3票までなので、票数の分だけ投票者を作る
  def vote_for(entry, count)
    count.times { create(:vote, user: create(:user), entry: entry) }
  end

  it "同じエントリーには2票目を投じられない" do
    entry = entry_in
    create(:vote, user: user, entry: entry)

    vote = build(:vote, user: user, entry: entry)

    expect(vote).to be_invalid
    expect(vote.errors[:base]).to include("同じエントリーには投票できません")
  end

  it "同じ部門には3票までしか投じられない" do
    3.times { create(:vote, user: user, entry: entry_in) }

    vote = build(:vote, user: user, entry: entry_in)

    expect(vote).to be_invalid
    expect(vote.errors[:base]).to include("1つの部門に投票できるのは3票までです")
  end

  it "票数は部門ごとに数える" do
    3.times { create(:vote, user: user, entry: entry_in) }
    drink = create(:category, category_name: :drink)

    expect(build(:vote, user: user, entry: entry_in(drink))).to be_valid
  end

  it "票数はイベントごとに数える" do
    3.times { create(:vote, user: user, entry: entry_in) }
    other_event_entry = create(:entry, event: create(:event), category: category)

    expect(build(:vote, user: user, entry: other_event_entry)).to be_valid
  end

  it "別のユーザーの票は自分の票数に数えない" do
    3.times { create(:vote, user: create(:user), entry: entry_in) }

    expect(build(:vote, user: user, entry: entry_in)).to be_valid
  end

  it "コメントは300文字まで" do
    expect(build(:vote, comment: "あ" * 300)).to be_valid
    expect(build(:vote, comment: "あ" * 301)).to be_invalid
  end

  it "同じエントリーへの重複はDBでも弾く" do
    entry = entry_in
    create(:vote, user: user, entry: entry)

    duplicate = build(:vote, user: user, entry: entry)

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe ".ranking_by_entry" do
    it "エントリー単位の得票数を多い順に3位まで返す" do
      first = create(:entry, event: event, category: category, title: "唐揚げ")
      second = create(:entry, event: event, category: category, title: "餃子")
      third = create(:entry, event: event, category: category, title: "肉じゃが")
      create(:entry, event: event, category: category, title: "おにぎり")
      vote_for(first, 3)
      vote_for(second, 2)
      vote_for(third, 1)

      rows = described_class.ranking_by_entry(event, category)

      expect(rows.map(&:title)).to eq [ "唐揚げ", "餃子", "肉じゃが" ]
      expect(rows.map(&:rank)).to eq [ 1, 2, 3 ]
      expect(rows.map(&:vote_count)).to eq [ 3, 2, 1 ]
    end

    it "同票は同順位にし、次の順位をその分だけ飛ばす" do
      vote_for(create(:entry, event: event, category: category), 2)
      vote_for(create(:entry, event: event, category: category), 2)
      vote_for(create(:entry, event: event, category: category), 1)

      expect(described_class.ranking_by_entry(event, category).map(&:rank)).to eq [ 1, 1, 3 ]
    end

    it "3位が同票で並んだときは4件目以降も載せる" do
      vote_for(create(:entry, event: event, category: category), 3)
      vote_for(create(:entry, event: event, category: category), 2)
      vote_for(create(:entry, event: event, category: category), 1)
      vote_for(create(:entry, event: event, category: category), 1)

      expect(described_class.ranking_by_entry(event, category).map(&:rank)).to eq [ 1, 2, 3, 3 ]
    end

    it "4位以下は載せない" do
      4.downto(1) { |count| vote_for(create(:entry, event: event, category: category), count) }

      expect(described_class.ranking_by_entry(event, category).map(&:vote_count)).to eq [ 4, 3, 2 ]
    end

    it "1票も入っていないエントリーは載せない" do
      create(:entry, event: event, category: category)

      expect(described_class.ranking_by_entry(event, category)).to be_empty
    end

    it "他の部門・他のイベントの票は数えない" do
      drink = create(:category, category_name: :drink)
      entry = create(:entry, event: event, category: category)
      vote_for(entry, 1)
      vote_for(create(:entry, event: event, category: drink), 3)
      vote_for(create(:entry, event: create(:event), category: category), 3)

      rows = described_class.ranking_by_entry(event, category)

      expect(rows.map(&:vote_count)).to eq [ 1 ]
      expect(rows.first.name).to eq entry.user.name
    end
  end

  describe ".ranking_by_user" do
    it "同じ人が同じ部門に出したエントリーの得票数を合算する" do
      user = create(:user, name: "もとひろ")
      vote_for(create(:entry, user: user, event: event, category: category), 2)
      vote_for(create(:entry, user: user, event: event, category: category), 2)
      vote_for(create(:entry, event: event, category: category), 3)

      rows = described_class.ranking_by_user(event, category)

      expect(rows.map(&:name).first).to eq "もとひろ"
      expect(rows.map(&:vote_count)).to eq [ 4, 3 ]
    end

    it "部門をまたいでは合算しない" do
      drink = create(:category, category_name: :drink)
      user = create(:user)
      vote_for(create(:entry, user: user, event: event, category: category), 2)
      vote_for(create(:entry, user: user, event: event, category: drink), 3)

      expect(described_class.ranking_by_user(event, category).map(&:vote_count)).to eq [ 2 ]
    end
  end
end
