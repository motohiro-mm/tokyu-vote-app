require "rails_helper"

RSpec.describe Talk do
  it "説明は300文字まで" do
    expect(build(:talk, description: "あ" * 300)).to be_valid
    expect(build(:talk, description: "あ" * 301)).to be_invalid
  end

  it "発表資料URLの空欄を nil に正規化する" do
    [ nil, "", "   " ].each do |url|
      talk = build(:talk, slide_url: url)
      expect(talk).to be_valid
      expect(talk.slide_url).to be_nil
    end
  end

  it "発表資料URLは前後の空白を除いた http または https を受け付ける" do
    [ "http://example.com", "https://example.com" ].each do |url|
      talk = build(:talk, slide_url: "  #{url}  ")
      expect(talk).to be_valid
      expect(talk.slide_url).to eq url
    end
    expect(build(:talk, slide_url: "https://example.com/" + "a" * 2028)).to be_valid
    expect(build(:talk, slide_url: "https://example.com/" + "a" * 2029)).to be_invalid
  end

  it "不正な発表資料URLを拒否し日本語で知らせる" do
    [ "javascript:alert(1)", "data:text/html,hi", "ftp://example.com", "example.com", "//example.com", "http://", "https://example.com/あ" ].each do |url|
      talk = build(:talk, slide_url: url)
      expect(talk).to be_invalid
      expect(talk.errors.full_messages).to include("発表資料URLは http または https の URL で入力してください")
      expect(talk.safe_slide_url).to be_nil
    end
  end

  it "votable は発表予定のものだけを返す" do
    event = create(:event)
    scheduled = create(:talk, event: event)
    create(:talk, event: event, status: :canceled)

    expect(event.talks.votable).to contain_exactly(scheduled)
  end

  it "投票開始後はステータスを変更できない" do
    event = create(:event, status: :preparing)
    talk = create(:talk, event: event)

    expect(talk.update(status: :canceled)).to be true

    event.open!
    expect(talk.reload.update(status: :scheduled)).to be false
    expect(talk.errors[:status]).to include("は投票開始後には変更できません")
  end

  it "投票開始後でもステータス以外は変更できる" do
    event = create(:event, status: :open)
    talk = create(:talk, event: event)

    expect(talk.update(title: "差し替え後のタイトル")).to be true
  end
end
