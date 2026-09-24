# 画面を触って確認するためのデータを作る。development 専用。
namespace :demo do
  desc "動作確認用のイベント・ユーザー・エントリーを作成する"
  task setup: :environment do
    abort "development でのみ実行できます" unless Rails.env.development?

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
end
