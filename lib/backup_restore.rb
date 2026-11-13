require "digest"
require "zip"

# backup:zip の zip を、今の環境の primary DB と Active Storage（Disk）へ戻す（backup:restore）。
# zip の中身は BackupArchive と同じ:
#   db/<DB ファイル名>                        今の環境の primary DB の場所へ置く
#   active_storage/<サービス名>/<キーのパス>   その Disk サービスの root へ置く
class BackupRestore
  class Error < StandardError; end

  attr_reader :path, :database_path, :blob_count, :missing_blob_keys, :mismatched_blob_keys

  def initialize(path)
    @path = Rails.root.join(path.to_s)
    @database_path = Rails.root.join(primary_db_config.database)
    @blob_count = 0
    @missing_blob_keys = []
    @mismatched_blob_keys = []
  end

  def ok?
    missing_blob_keys.empty? && mismatched_blob_keys.empty?
  end

  def restore!
    ensure_environment!
    raise Error, "zip がありません: #{path}" unless path.file?

    db_temp = nil
    begin
      Zip::File.open(path.to_s) do |zip|
        db_entry, storage_entries = read_entries(zip)
        ensure_can_replace_database!
        db_temp = extract_database(db_entry)
        check_integrity!(db_temp)
        storage_entries.each do |entry, service_name, relative|
          extract_storage(entry, service_name, relative)
        end
      end
      install_database!(db_temp)
      db_temp = nil
      verify!
    rescue Zip::Error
      raise Error, "zip を読めません: #{path}"
    ensure
      FileUtils.rm_f(db_temp) if db_temp
    end
    self
  end

  private

  def primary_db_config
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
  end

  def ensure_environment!
    return if Rails.env.local? || ENV["ALLOW_BACKUP_RESTORE"] == "1"

    raise Error, "development と test 以外では実行できません（実行する場合は ALLOW_BACKUP_RESTORE=1）"
  end

  def force?
    ENV["FORCE"] == "1"
  end

  def ensure_can_replace_database!
    return if force?
    return unless database_path.file?

    if destination_has_rows?
      raise Error, "戻し先の DB にデータがあります（#{database_path}）。上書きするときは FORCE=1 を付けてください"
    end
  rescue SQLite3::Exception
    raise Error, "戻し先の DB を読めません（#{database_path}）。上書きするときは FORCE=1 を付けてください"
  end

  def destination_has_rows?
    SQLite3::Database.open(database_path.to_s, readonly: true) do |db|
      db.busy_timeout = 5000
      db.results_as_hash = false
      tables = db.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'").flatten
      ignored = %w[schema_migrations ar_internal_metadata]
      (tables - ignored).any? { |table| db.get_first_value("SELECT 1 FROM #{quote_identifier(table)} LIMIT 1") }
    end
  end

  def quote_identifier(name)
    raise Error, "戻し先の DB に想定外のテーブルがあります: #{name}" unless name.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/)

    "\"#{name}\""
  end

  def read_entries(zip)
    db_entries = []
    storage_entries = []

    zip.each do |entry|
      parts = safe_parts!(entry.name)
      if entry.directory?
        raise Error, "想定外のエントリです: #{entry.name}" unless parts.first.in?(%w[db active_storage])

        next
      end
      raise Error, "想定外のエントリです: #{entry.name}" unless entry.file?

      if parts.first == "db" && parts.size == 2
        db_entries << entry
      elsif parts.first == "active_storage" && parts.size >= 3
        storage_entries << [ entry, parts[1], parts[2..].join("/") ]
      else
        raise Error, "想定外のエントリです: #{entry.name}"
      end
    end

    raise Error, "zip に DB ファイルがありません" if db_entries.empty?
    raise Error, "zip の DB ファイルが複数あります" if db_entries.size > 1

    [ db_entries.first, storage_entries ]
  end

  # `..` や絶対パスは、cleanpath したあとに消えて見えることがある（active_storage/test/../../x など）
  def safe_parts!(name)
    text = name.to_s
    if text.empty? || text.include?("\\") || text.include?("\0") || absolute_entry?(text)
      raise Error, "想定外のエントリです: #{text}"
    end

    parts = text.delete_suffix("/").split("/")
    if parts.empty? || parts.any? { |part| part.empty? || part == "." || part == ".." }
      raise Error, "想定外のエントリです: #{text}"
    end
    parts
  rescue ArgumentError, Encoding::CompatibilityError
    raise Error, "想定外のエントリです: #{name}"
  end

  def absolute_entry?(text)
    text.start_with?("/") || text.match?(/\A[A-Za-z]:/) || Pathname.new(text).absolute?
  end

  def extract_database(entry)
    temp = database_temp_path
    extract_file(entry, temp)
    File.open(temp, "rb") { |file| file.fsync }
    temp
  end

  def database_temp_path
    FileUtils.mkdir_p(database_path.dirname)
    database_path.dirname.join(".#{database_path.basename}.restore-#{SecureRandom.hex(4)}")
  end

  def extract_storage(entry, service_name, relative)
    dest = storage_destination(disk_service!(service_name).root, relative)
    extract_file(entry, dest)
  end

  def disk_service!(name)
    service = ActiveStorage::Blob.services.fetch(name)
    return service if service.respond_to?(:path_for) && service.respond_to?(:root)

    raise Error, "Disk 以外のサービス（#{name}）のファイルは戻せません"
  rescue KeyError
    raise Error, "Active Storage のサービスが見つかりません: #{name}"
  end

  def storage_destination(root, relative)
    root_path = File.expand_path(root.to_s)
    dest = File.expand_path(relative.to_s, root_path)
    prefix = "#{root_path}#{File::SEPARATOR}"
    raise Error, "想定外のエントリです: active_storage/#{relative}" unless dest.start_with?(prefix)

    Pathname(dest)
  end

  def extract_file(entry, dest)
    FileUtils.mkdir_p(dest.dirname)
    entry.get_input_stream do |input|
      File.open(dest, "wb") do |output|
        IO.copy_stream(input, output)
      end
    end
    dest
  end

  def check_integrity!(db_file)
    result = SQLite3::Database.open(db_file.to_s, readonly: true) do |db|
      db.busy_timeout = 5000
      db.get_first_value("PRAGMA integrity_check")
    end
    raise Error, "DB の integrity_check が通りません: #{result}" unless result == "ok"
  end

  # 展開の途中で落ちても戻し先が半分だけ書き換わらないよう、検査が通ったファイルを最後に置く。
  # 古い WAL が残っていると新しい DB を開いたときに混ざるので、失敗したら戻せるよう先に脇へどける。
  def install_database!(temp)
    ActiveRecord::Base.connection_pool.disconnect!

    aside = move_aside(wal_path, shm_path)
    begin
      File.rename(temp.to_s, database_path.to_s)
    rescue StandardError
      move_back(aside)
      raise
    end
    aside.each { |_path, moved| FileUtils.rm_f(moved) }
  end

  def move_aside(*paths)
    paths.filter_map do |path|
      next unless path.exist?

      moved = Pathname("#{path}.before-restore-#{Process.pid}")
      File.rename(path.to_s, moved.to_s)
      [ path, moved ]
    end
  end

  def move_back(aside)
    aside.reverse_each do |path, moved|
      File.rename(moved.to_s, path.to_s) if moved.exist? && !path.exist?
    end
  end

  def wal_path
    Pathname("#{database_path}-wal")
  end

  def shm_path
    Pathname("#{database_path}-shm")
  end

  def verify!
    # 置き換え前の接続が覚えていたテーブル情報のまま読まない
    ActiveRecord::Base.connection_pool.schema_cache.clear!
    ActiveStorage::Blob.find_each do |blob|
      file = blob_file(blob)
      unless file.file?
        missing_blob_keys << blob.key
        next
      end

      if Digest::MD5.file(file.to_s).base64digest == blob.checksum
        @blob_count += 1
      else
        mismatched_blob_keys << blob.key
      end
    end
  end

  def blob_file(blob)
    service = blob.service
    raise Error, "Disk 以外のサービス（#{blob.service_name}）のファイルは確かめられません" unless service.respond_to?(:path_for)

    Pathname(service.path_for(blob.key))
  end
end
