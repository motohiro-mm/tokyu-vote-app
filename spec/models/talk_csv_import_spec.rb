require "rails_helper"

RSpec.describe TalkCsvImport do
  let(:event) { create(:event) }

  def import(text)
    described_class.new(event, text)
  end

  it "ヘッダ付きの CSV から LT を作る" do
    result = import("登壇者名,LTタイトル\nとうだんしゃ1,Ruby の話\nとうだんしゃ2,SQLite の話\n")

    expect(result.save).to be true
    expect(event.talks.pluck(:description)).to all(be_nil)
    expect(event.talks.pluck(:slide_url)).to all(be_nil)
    expect(event.talks.pluck(:user_name, :title)).to contain_exactly(
      [ "とうだんしゃ1", "Ruby の話" ], [ "とうだんしゃ2", "SQLite の話" ]
    )
  end

  it "任意の説明列を読み取り、空欄は nil にする" do
    result = import("登壇者名,LTタイトル,説明\n一人目,Ruby,  説明文  \n二人目,SQLite,  \n")

    expect(result.save).to be true
    expect(event.talks.order(:id).pluck(:description)).to eq [ "説明文", nil ]
    expect(event.talks.pluck(:slide_url)).to all(be_nil)
  end

  it "任意の発表資料URL列を読み取り、空欄は nil にする" do
    result = import("登壇者名,LTタイトル,発表資料URL\n一人目,Ruby,  https://example.com/slides  \n二人目,SQLite,  \n")

    expect(result.save).to be true
    expect(event.talks.order(:id).pluck(:slide_url)).to eq [ "https://example.com/slides", nil ]
  end

  it "不正または長すぎる発表資料URLがあれば行番号を知らせ、1 件も登録しない" do
    [ "javascript:alert(1)", "https://example.com/" + "a" * 2029 ].each do |url|
      result = import("登壇者名,LTタイトル,発表資料URL\n一人目,Ruby,https://example.com\n二人目,SQLite,#{url}\n")
      expect(result.save).to be false
      expect(result.errors.first).to include("3 行目", "発表資料URL")
      expect(event.talks.count).to eq 0
    end
  end

  it "説明が長すぎる行があれば行番号を知らせ、1 件も登録しない" do
    result = import("登壇者名,LTタイトル,説明\n一人目,Ruby,説明\n二人目,SQLite,#{"あ" * 301}\n")

    expect(result.save).to be false
    expect(result.errors.first).to include("3 行目", "説明")
    expect(event.talks.count).to eq 0
  end

  it "Excel が付ける BOM と前後の空白を取り除く" do
    result = import("﻿登壇者名,LTタイトル\n とうだんしゃ , Ruby の話 \n")

    expect(result.save).to be true
    expect(event.talks.first).to have_attributes(user_name: "とうだんしゃ", title: "Ruby の話")
  end

  it "ヘッダが足りなければ登録しない" do
    result = import("名前,タイトル\nとうだんしゃ,Ruby の話\n")

    expect(result.save).to be false
    expect(result.errors).to include("ヘッダに 登壇者名、LTタイトル がありません")
  end

  it "不正な行があれば行番号を知らせ、1 件も登録しない" do
    result = import("登壇者名,LTタイトル\nとうだんしゃ1,Ruby の話\n,SQLite の話\n")

    expect(result.save).to be false
    expect(result.errors).to include("3 行目: 登壇者名を入力してください")
    expect(Talk.count).to eq 0
  end

  it "行が無ければ登録しない" do
    result = import("登壇者名,LTタイトル\n")

    expect(result.save).to be false
    expect(result.errors).to include("登録する行がありません")
  end

  it "UTF-8 でなければ読み込めないと知らせる" do
    result = import("登壇者名,LTタイトル\nとうだんしゃ,話\n".encode(Encoding::Shift_JIS))

    expect(result.save).to be false
    expect(result.errors).to include("CSV として読み込めませんでした。UTF-8 で保存してください")
  end
end
