# 画面を触って確認するためのデータを作る。development（と、タスク自体を確かめる test）専用。
namespace :demo do
  desc "動作確認用のイベント・ユーザー・エントリーを作成する"
  task setup: :environment do
    abort "development でのみ実行できます" unless Rails.env.local?

    Rake::Task["db:seed"].invoke

    admin = User.find_or_create_by!(provider: "demo", uid: "admin") do |user|
      user.name = "かんりしゃ"
      user.admin = true
    end
    members = 3.times.map do |i|
      User.find_or_create_by!(provider: "demo", uid: "member#{i + 1}") do |user|
        user.name = "さんかしゃ#{i + 1}"
      end
    end

    event = Event.find_or_create_by!(title: "TokyuRuby会議デモ") { |e| e.status = :open }

    food = Category.find_by!(category_name: :food)
    drink = Category.find_by!(category_name: :drink)

    [ [ food, "唐揚げ" ], [ food, "ポテトサラダ" ], [ drink, "日本酒" ], [ drink, "クラフトビール" ] ].each_with_index do |(category, title), i|
      event.entries.find_or_create_by!(title: title) do |entry|
        entry.category = category
        entry.user = members[i % members.size]
        entry.description = "#{title}です。"
      end
    end

    [ "Rubyの話", "SQLiteの話", "Kamalの話", "Hotwireの話" ].each_with_index do |title, i|
      event.talks.find_or_create_by!(title: title) do |talk|
        talk.user_name = "とうだんしゃ#{i + 1}"
      end
    end

    puts "できました: #{event.title}（#{event.status_label}）"
    puts "ログイン画面 http://localhost:3000/login から #{admin.name} を選ぶと管理画面に入れます"
  end

  desc "投票と集計を終えて結果を公開済みのイベントを作成する（結果発表の画面と静的書き出しの確認用）"
  task results: :environment do
    abort "development でのみ実行できます" unless Rails.env.local?

    Rake::Task["demo:setup"].invoke

    admin = User.find_by!(provider: "demo", uid: "admin")
    # 投票者が多いほど順位とコメントが賑やかになるので、demo:setup の 3 人に加えて 5 人足す
    voters = 8.times.map do |i|
      User.find_or_create_by!(provider: "demo", uid: "member#{i + 1}") do |user|
        user.name = "さんかしゃ#{i + 1}"
      end
    end
    # 持ち込みは 4 人に絞り、同じ人が複数持ち込むことで単品王と合算王の顔ぶれが変わるようにする
    cooks = voters.first(4)

    event = Event.find_or_create_by!(title: "TokyuRuby会議デモ（結果公開済み）") { |e| e.status = :closed }
    event.update!(status: :closed) unless event.closed?

    food = Category.find_by!(category_name: :food)
    drink = Category.find_by!(category_name: :drink)

    entries = {
      # [部門, タイトル, 持ち込んだ人の番号, 説明]
      "唐揚げ" => [ food, 0, "にんにく醤油に一晩漬けました。" ],
      "ポテトサラダ" => [ food, 0, "燻製ベーコン入りです。" ],
      "肉じゃが" => [ food, 1, "祖母のレシピです。" ],
      "餃子" => [ food, 2, "皮から手作りしました。" ],
      "ティラミス" => [ food, 3, "マスカルポーネたっぷり。" ],
      "日本酒" => [ drink, 1, "新潟の純米吟醸です。" ],
      "クラフトビール" => [ drink, 2, "近所のブルワリーのIPA。" ],
      "梅酒" => [ drink, 2, "去年漬けた自家製。" ],
      "ウイスキー" => [ drink, 3, "アイラのシングルモルト。" ]
    }.to_h do |title, (category, cook_index, description)|
      entry = event.entries.find_or_create_by!(title: title) do |e|
        e.category = category
        e.user = cooks[cook_index]
        e.description = description
      end
      [ title, entry ]
    end

    talks = {
      "Rubyの話" => "とうだんしゃ1",
      "SQLiteの話" => "とうだんしゃ2",
      "Kamalの話" => "とうだんしゃ3",
      "Hotwireの話" => "とうだんしゃ4"
    }.to_h do |title, user_name|
      [ title, event.talks.find_or_create_by!(title: title) { |t| t.user_name = user_name } ]
    end
    # 結果画面にキャンセル済み LT が出ないことも確かめられるようにする
    event.talks.find_or_create_by!(title: "当日欠席になった話") do |t|
      t.user_name = "とうだんしゃ5"
      t.status = :canceled
    end

    # 1 人 1 部門 3 票まで。飯王は単品 1 位が同票で並び、合算王は 2 品持ち込んだ人が逆転するように配る
    food_ballots = [
      [ "唐揚げ", "肉じゃが", "餃子" ],
      [ "唐揚げ", "肉じゃが", "ポテトサラダ" ],
      [ "肉じゃが", "餃子", "ティラミス" ],
      [ "唐揚げ", "ポテトサラダ", "ティラミス" ],
      [ "肉じゃが", "唐揚げ", "ポテトサラダ" ],
      [ "餃子", "ティラミス" ],
      [ "唐揚げ", "ポテトサラダ" ],
      [ "肉じゃが" ]
    ]
    drink_ballots = [
      [ "日本酒", "クラフトビール", "梅酒" ],
      [ "日本酒", "ウイスキー" ],
      [ "クラフトビール", "梅酒", "ウイスキー" ],
      [ "日本酒", "梅酒" ],
      [ "日本酒", "クラフトビール", "ウイスキー" ],
      [ "梅酒" ],
      [ "日本酒" ],
      [ "クラフトビール", "ウイスキー" ]
    ]
    talk_ballots = [
      [ "Rubyの話", "SQLiteの話", "Kamalの話" ],
      [ "Rubyの話", "Hotwireの話" ],
      [ "SQLiteの話", "Kamalの話" ],
      [ "Rubyの話", "SQLiteの話", "Hotwireの話" ],
      [ "Rubyの話" ],
      [ "SQLiteの話", "Kamalの話" ],
      [ "Rubyの話", "Hotwireの話" ],
      [ "SQLiteの話" ]
    ]
    comments = {
      "唐揚げ" => [ "衣がザクザクで最高でした", "ビールが進む", nil, nil, "冷めても美味しい" ],
      "肉じゃが" => [ "味が染みてる", nil, "おふくろの味", nil, nil ],
      "餃子" => [ "皮がもちもち", nil, nil ],
      "ティラミス" => [ nil, "甘さ控えめで良い", nil ],
      "日本酒" => [ "キレがある", nil, nil, "料理に合う", nil, nil ],
      "梅酒" => [ "自家製なのがすごい", nil, nil, nil ],
      "Rubyの話" => [ "笑いました", nil, "資料がきれい", nil, nil ],
      "SQLiteの話" => [ nil, "本番で使う勇気が出た", nil, nil, nil ]
    }
    comment_for = ->(title) { comments.fetch(title, []).shift }

    voters.each_with_index do |voter, i|
      food_ballots[i].each do |title|
        entries.fetch(title).votes.find_or_create_by!(user: voter) { |v| v.comment = comment_for.call(title) }
      end
      drink_ballots[i].each do |title|
        entries.fetch(title).votes.find_or_create_by!(user: voter) { |v| v.comment = comment_for.call(title) }
      end
      talk_ballots[i].each do |title|
        talks.fetch(title).talk_votes.find_or_create_by!(user: voter) { |v| v.comment = comment_for.call(title) }
      end
    end

    puts "できました: #{event.title}（#{event.status_label}）"
    puts "ログイン画面 http://localhost:3000/login から #{admin.name} を選ぶと管理画面の集計、誰でも http://localhost:3000/events/#{event.id} から結果を見られます"
    puts "静的書き出しは bin/rails export:static"
  end
end
