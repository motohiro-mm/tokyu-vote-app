require "rails_helper"

RSpec.describe TalkCsvImport do
  let(:event) { create(:event) }

  def import(text)
    described_class.new(event, text)
  end

  it "ヘッダ付きの CSV から LT を作る" do
    result = import("登壇者名,LTタイトル\nとうだんしゃ1,Ruby の話\nとうだんしゃ2,SQLite の話\n")

    expect(result.save).to be true
    expect(event.talks.pluck(:user_name, :title)).to contain_exactly(
      [ "とうだんしゃ1", "Ruby の話" ], [ "とうだんしゃ2", "SQLite の話" ]
    )
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
