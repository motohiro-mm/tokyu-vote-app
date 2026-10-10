require "csv"

# LT候補を CSV から一括登録する。
# 1 行でも不正があれば 1 件も登録しない。途中まで入った状態は、どこまで入ったか画面で追えず
# 二重登録の元になるため。
class TalkCsvImport
  # ヘッダは画面のラベル（ja.yml の attributes.talk）と同じ日本語にし、見本をそのまま埋めればよいようにする
  HEADERS = { user_name: "登壇者名", title: "LTタイトル" }.freeze

  attr_reader :talks, :errors

  def initialize(event, csv_text)
    @event = event
    @csv_text = csv_text
    @talks = []
    @errors = []
  end

  def save
    build
    return false if @errors.any?

    Talk.transaction { @talks.each(&:save!) }
    true
  end

  private

  def build
    rows = parse
    return if rows.nil?

    missing = HEADERS.values - rows.headers.compact
    if missing.any?
      @errors << "ヘッダに #{missing.join('、')} がありません"
      return
    end

    rows.each_with_index do |row, index|
      talk = @event.talks.build(user_name: row[HEADERS[:user_name]]&.strip, title: row[HEADERS[:title]]&.strip)
      @errors << "#{index + 2} 行目: #{talk.errors.full_messages.to_sentence}" if talk.invalid?
      @talks << talk
    end

    @errors << "登録する行がありません" if @talks.empty?
  end

  # Excel で保存した CSV は BOM 付きの UTF-8 になるため、先頭の BOM を取り除く
  def parse
    text = @csv_text.dup.force_encoding(Encoding::UTF_8).delete_prefix("﻿")
    raise ArgumentError unless text.valid_encoding?

    CSV.parse(text, headers: true, skip_blanks: true)
  rescue CSV::MalformedCSVError, ArgumentError
    @errors << "CSV として読み込めませんでした。UTF-8 で保存してください"
    nil
  end
end
