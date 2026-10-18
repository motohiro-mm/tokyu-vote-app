# 停止時の退避用。primary DB と Active Storage のファイルを 1 つの zip にまとめる（docs/deploy.md の「データを退避する」）。
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
end
