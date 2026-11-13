require "rails_helper"
require "rake"

RSpec.describe "backup:zip" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task["backup:zip"] }
  let(:dir) { Dir.mktmpdir }
  let(:output_path) { File.join(dir, "backup.zip") }
  let(:db_file_name) { File.basename(ActiveRecord::Base.connection_db_config.database) }

  # バックアップは別の接続で DB ファイルのコミット済みの内容を読むため、テスト用のトランザクションに包まない
  self.use_transactional_tests = false

  before { task.reenable }

  after do
    FileUtils.rm_rf(dir)

    connection = ActiveRecord::Base.connection
    connection.disable_referential_integrity do
      (connection.tables - %w[schema_migrations ar_internal_metadata]).each do |table|
        connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
      end
    end
  end

  def run_task(path)
    task.invoke(path)
  end

  it "DB と添付画像を 1 つの zip に入れる" do
    entry = create(:entry, title: "唐揚げ")
    entry.image.attach(io: StringIO.new("png-bytes"), filename: "karaage.png", content_type: "image/png")
    key = entry.image.blob.key

    expect { run_task(output_path) }.to output(/zip を作りました.*Active Storage のファイル: 1 件/m).to_stdout

    Zip::File.open(output_path) do |zip|
      image = zip.find_entry("active_storage/test/#{key[0..1]}/#{key[2..3]}/#{key}")
      expect(image.get_input_stream.read).to eq "png-bytes"

      db_copy = File.join(dir, "copy.sqlite3")
      File.binwrite(db_copy, zip.find_entry("db/#{db_file_name}").get_input_stream.read)
      SQLite3::Database.new(db_copy) do |db|
        expect(db.get_first_value("SELECT title FROM entries WHERE id = ?", entry.id)).to eq "唐揚げ"
        expect(db.get_first_value("SELECT key FROM active_storage_blobs WHERE key = ?", key)).to eq key
      end
    end
  end

  it "出力先にファイルがあれば上書きせずエラーで終了する" do
    File.write(output_path, "existing")

    expect { run_task(output_path) }.to raise_error(SystemExit).and output(/すでにあります/).to_stderr
    expect(File.read(output_path)).to eq "existing"
  end

  it "出力先を省略すると storage/backups/ に日時付きの名前で作る" do
    path = BackupArchive.default_path(Time.zone.local(2026, 10, 18, 15, 4, 5))

    expect(path).to eq Rails.root.join("storage/backups/tokyu-vote-app-test-20261018-150405.zip")
  end
end
