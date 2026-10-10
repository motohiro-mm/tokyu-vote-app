namespace :export do
  # bin/dev を動かしていないと CSS のビルドが古いまま書き出されるため、先にビルドし直す
  desc "結果公開済みのイベントを静的サイトとして public_export/ に書き出す"
  task static: [ "tailwindcss:build", :environment ] do
    out = Rails.root.join("public_export")
    count = StaticExport.new(out).run

    puts "#{out} に書き出しました（#{count} ファイル）"
  end
end
