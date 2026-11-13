require "tmpdir"
require "zip"

# 停止時の退避用に、primary DB と Active Storage のファイルを 1 つの zip にまとめる（backup:zip）。
# zip の中身:
#   db/<DB ファイル名>                        primary DB の複製
#   active_storage/<サービス名>/<キーのパス>   Active Storage のファイル（サービスの root からの相対パス）
class BackupArchive
  class Error < StandardError; end

  attr_reader :path, :database_path, :blob_count, :missing_blob_keys

  def self.default_path(now = Time.current)
    Rails.root.join("storage/backups/tokyu-vote-app-#{Rails.env}-#{now.strftime('%Y%m%d-%H%M%S')}.zip")
  end

  def initialize(path)
    @path = Rails.root.join(path.to_s)
    @database_path = Rails.root.join(primary_db_config.database)
    @blob_count = 0
    @missing_blob_keys = []
  end

  def create!
    raise Error, "#{path} はすでにあります。別の出力先を指定してください" if path.exist?

    FileUtils.mkdir_p(path.dirname)
    begin
      Dir.mktmpdir do |dir|
        db_copy = File.join(dir, database_path.basename)
        copy_database(db_copy)

        Zip::File.open(path.to_s, create: true) do |zip|
          zip.add("db/#{database_path.basename}", db_copy)
          add_blobs(zip)
        end
      end
    rescue StandardError
      FileUtils.rm_f(path)
      raise
    end
    self
  end

  private

  def primary_db_config
    ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
  end

  # 稼働中の DB をそのまま cp すると書き込み途中や WAL に残った分が欠けるため、
  # SQLite のオンラインバックアップ API で、コミット済みの整合した状態を複製する
  def copy_database(dest)
    raise Error, "DB ファイルがありません: #{database_path}" unless database_path.exist?

    SQLite3::Database.new(database_path.to_s, readonly: true) do |source|
      source.busy_timeout = 5000
      SQLite3::Database.new(dest) do |copy|
        backup = SQLite3::Backup.new(copy, "main", source, "main")
        result = backup.step(-1)
        backup.finish
        raise Error, "DB の複製に失敗しました（SQLite の結果コード: #{result}）" unless result == SQLite3::Constants::ErrorCode::DONE

        # WAL モードのまま複製すると開くたびに -wal ファイルが作られるため、単体で扱える形にしておく
        copy.execute("PRAGMA journal_mode = DELETE")
      end
    end
  end

  def add_blobs(zip)
    ActiveStorage::Blob.find_each do |blob|
      service = blob.service
      raise Error, "Disk 以外のサービス（#{blob.service_name}）のファイルは退避できません" unless service.respond_to?(:path_for)

      file = Pathname(service.path_for(blob.key))
      unless file.exist?
        missing_blob_keys << blob.key
        next
      end

      zip.add("active_storage/#{blob.service_name}/#{file.relative_path_from(service.root)}", file.to_s)
      @blob_count += 1
    end
  end
end
