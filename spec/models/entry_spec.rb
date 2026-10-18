require "rails_helper"

RSpec.describe Entry do
  it "LT王の部門では登録できない" do
    entry = build(:entry, category: create(:category, category_name: :talk))

    expect(entry).to be_invalid
    expect(entry.errors[:category]).to include("にLT王は指定できません")
  end

  it "説明は300文字まで" do
    expect(build(:entry, description: "あ" * 300)).to be_valid
    expect(build(:entry, description: "あ" * 301)).to be_invalid
  end

  it "対応していない形式の画像は登録できない" do
    entry = build(:entry)
    entry.image.attach(
      io: StringIO.new("dummy"), filename: "entry.svg", content_type: "image/svg+xml"
    )

    expect(entry).to be_invalid
    expect(entry.errors[:image]).to include("は JPEG / PNG のみ登録できます")
  end

  it "GIF は登録できない" do
    entry = build(:entry)
    entry.image.attach(io: StringIO.new("dummy"), filename: "entry.gif", content_type: "image/gif")

    expect(entry).to be_invalid
  end

  it "上限を超える大きさの画像は登録できない" do
    entry = build(:entry)
    entry.image.attach(
      io: StringIO.new("a" * (Entry::IMAGE_MAX_SIZE + 1)), filename: "entry.jpg", content_type: "image/jpeg"
    )

    expect(entry).to be_invalid
    expect(entry.errors[:image]).to include("は 20MB 以下にしてください")
  end

  it "上限ちょうどの大きさの画像は登録できる" do
    entry = build(:entry)
    entry.image.attach(
      io: StringIO.new("a" * Entry::IMAGE_MAX_SIZE), filename: "entry.jpg", content_type: "image/jpeg"
    )

    expect(entry.errors[:image]).to be_empty
  end

  it "画像は任意" do
    expect(build(:entry)).to be_valid
  end

  it "登録時にユーザーの名前を写し、渡した名前やその後の改名では変わらない" do
    user = create(:user, name: "もとひろ")
    entry = create(:entry, user: user, user_name: "別人")

    expect(entry.user_name).to eq "もとひろ"

    user.update!(name: "あたらしい名前")

    expect { entry.update!(user_name: "さらに別人") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    expect(entry.reload.user_name).to eq "もとひろ"
  end

  it "削除すると投じられた票も消える" do
    entry = create(:entry)
    create(:vote, entry: entry)

    expect { entry.destroy }.to change(Vote, :count).by(-1)
  end
end
