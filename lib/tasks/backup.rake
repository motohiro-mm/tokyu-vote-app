# 停止時の退避用。primary DB と Active Storage のファイルを 1 つの zip にまとめる（docs/deploy.md の「データを退避する」）。
# backup:restore はその zip を development / test の primary DB と Disk サービスへ戻して確かめる。
namespace :backup do
  desc "primary DB と Active Storage のファイルを 1 つの zip にまとめる（backup:zip[出力先]。省略時は storage/backups/ に日時付きで作る）"
  task :zip, [ :output ] => :environment do |_task, args|
    archive = BackupArchive.new(args[:output].presence || BackupArchive.default_path).create!

    puts "zip を作りました: #{archive.path}"
    puts "  DB: #{archive.database_path}"
    puts "  Active Storage のファイル: #{archive.blob_count} 件"
    if archive.missing_blob_keys.any?
      warn "  ファイルが見つからず入れられなかった blob: #{archive.missing_blob_keys.size} 件（#{archive.missing_blob_keys.join(', ')}）"
    end
  rescue BackupArchive::Error => e
    abort e.message
  end

  desc "backup:zip の zip を primary DB と Active Storage に戻し、integrity_check と checksum を確かめる（backup:restore[zip]。development と test のみ。データがあるときは FORCE=1）"
  task :restore, [ :zip ] => :environment do |_task, args|
    abort "zip のパスを指定してください（例: bin/rails \"backup:restore[tmp/backup.zip]\"）" if args[:zip].blank?

    restored = BackupRestore.new(args[:zip]).restore!

    puts "zip を戻しました: #{restored.path}"
    puts "  DB: #{restored.database_path}（integrity_check: ok）"
    puts "  Active Storage のファイル: #{restored.blob_count} 件"
    if restored.missing_blob_keys.any?
      warn "  ファイルが見つからない blob: #{restored.missing_blob_keys.size} 件（#{restored.missing_blob_keys.join(', ')}）"
    end
    if restored.mismatched_blob_keys.any?
      warn "  checksum が一致しない blob: #{restored.mismatched_blob_keys.size} 件（#{restored.mismatched_blob_keys.join(', ')}）"
    end
    abort "blob のファイルが欠けるか checksum が一致しません" unless restored.ok?
  rescue BackupRestore::Error => e
    abort e.message
  end
end
