require "rails_helper"
require "rake"
require "zip"
require "zlib"

RSpec.describe "backup:restore" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:zip_task) { Rake::Task["backup:zip"] }
  let(:task) { Rake::Task["backup:restore"] }
  let(:dir) { Dir.mktmpdir }
  let(:zip_path) { File.join(dir, "backup.zip") }
  let(:db_file_name) { File.basename(ActiveRecord::Base.connection_db_config.database) }

  # backup:zip はコミット済みの内容を別接続で読む。restore は DB ファイル自体を置き換える
  self.use_transactional_tests = false

  before do
    zip_task.reenable
    task.reenable
  end

  after do
    FileUtils.rm_rf(dir)
    cleanup_tables
  end

  def storage_entry(key)
    "active_storage/test/#{key[0..1]}/#{key[2..3]}/#{key}"
  end

  def with_empty_destination
    directory = Dir.mktmpdir
    db_path = File.join(directory, "empty.sqlite3")
    storage_root = File.join(directory, "storage")
    FileUtils.mkdir_p(storage_root)

    db_config = ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "primary")
    original_database = db_config.database
    service = ActiveStorage::Blob.services.fetch(:test)
    original_root = service.root

    ActiveRecord::Base.connection_pool.disconnect!
    db_config._database = db_path
    service.root = storage_root
    yield db_path, storage_root
  ensure
    begin
      ActiveRecord::Base.connection_pool.disconnect!
      db_config._database = original_database if db_config && original_database
      service.root = original_root if service && original_root
      ActiveRecord::Base.establish_connection
    ensure
      FileUtils.rm_rf(directory) if directory
    end
  end

  def cleanup_tables
    connection = ActiveRecord::Base.connection
    connection.disable_referential_integrity do
      (connection.tables - %w[schema_migrations ar_internal_metadata]).each do |table|
        connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
      end
    end
  end

  # rubyzip は "/" で始まる名前を作れないので、絶対パスのエントリだけ生の zip を書く
  def write_stored_zip(path, entries)
    dos_time = 12 << 11
    dos_date = ((2026 - 1980) << 9) | (10 << 5) | 21
    File.open(path, "wb") do |io|
      central = entries.map do |name, content|
        data = content.b
        name_bytes = name.b
        crc = Zlib.crc32(data)
        offset = io.pos
        io.write([ 0x04034b50, 10, 0, 0, dos_time, dos_date, crc, data.bytesize, data.bytesize, name_bytes.bytesize, 0 ].pack("VvvvvvVVVvv"))
        io.write(name_bytes)
        io.write(data)
        [ offset, name_bytes, crc, data.bytesize ]
      end
      central_offset = io.pos
      central.each do |offset, name_bytes, crc, size|
        io.write([ 0x02014b50, 20, 10, 0, 0, dos_time, dos_date, crc, size, size, name_bytes.bytesize, 0, 0, 0, 0, 0, offset ].pack("VvvvvvvVVVvvvvvVV"))
        io.write(name_bytes)
      end
      io.write([ 0x06054b50, 0, 0, central.size, central.size, io.pos - central_offset, central_offset, 0 ].pack("VvvvvVVv"))
    end
  end

  it "空の DB と storage に行と画像を戻し、checksum が一致する" do
    entry = create(:entry, title: "唐揚げ")
    entry.image.attach(io: StringIO.new("png-bytes"), filename: "karaage.png", content_type: "image/png")
    key = entry.image.blob.key
    user_name = entry.user.name
    event_title = entry.event.title
    original_image = entry.image.blob.service.path_for(key)

    zip_task.invoke(zip_path)
    Zip::File.open(zip_path) { |zip| zip.rename("db/#{db_file_name}", "db/production.sqlite3") }
    entry.update!(title: "改ざん")
    File.binwrite(original_image, "tampered")

    with_empty_destination do |db_path, storage_root|
      SQLite3::Database.open(db_path) do |db|
        db.execute("CREATE TABLE schema_migrations (version varchar)")
        db.execute("INSERT INTO schema_migrations (version) VALUES ('1')")
        db.execute("CREATE TABLE users (id integer)")
        db.execute("CREATE TABLE events (id integer)")
      end

      expect { task.invoke(zip_path) }.to output(/zip を戻しました.*integrity_check: ok.*Active Storage のファイル: 1 件/m).to_stdout

      restored = Entry.find(entry.id)
      expect(restored.title).to eq "唐揚げ"
      expect(restored.user.name).to eq user_name
      expect(restored.event.title).to eq event_title
      expect(restored.image.download).to eq "png-bytes"

      blob = restored.image.blob
      file = blob.service.path_for(key)
      expect(file).to start_with("#{storage_root}/")
      expect(Digest::MD5.file(file).base64digest).to eq blob.checksum
      expect(blob.checksum).to eq Digest::MD5.base64digest("png-bytes")
      expect(File.expand_path(ActiveRecord::Base.connection_db_config.database)).to eq File.expand_path(db_path)
    end

    expect(entry.reload.title).to eq "改ざん"
    expect(File.binread(original_image)).to eq "tampered"
  end

  it "既存データがあると FORCE なしで止まる" do
    entry = create(:entry, title: "唐揚げ")
    entry.image.attach(io: StringIO.new("png-bytes"), filename: "karaage.png", content_type: "image/png")
    image = entry.image.blob.service.path_for(entry.image.blob.key)
    zip_task.invoke(zip_path)
    entry.update!(title: "改ざん")
    File.binwrite(image, "tampered")

    expect { task.invoke(zip_path) }.to raise_error(SystemExit).and output(/FORCE=1/).to_stderr
    expect(entry.reload.title).to eq "改ざん"
    expect(File.binread(image)).to eq "tampered"
  end

  it "FORCE=1 では既存の DB と画像を上書きする" do
    entry = create(:entry, title: "唐揚げ")
    entry.image.attach(io: StringIO.new("png-bytes"), filename: "karaage.png", content_type: "image/png")
    image = entry.image.blob.service.path_for(entry.image.blob.key)
    zip_task.invoke(zip_path)
    entry.update!(title: "改ざん")
    File.binwrite(image, "tampered")

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("FORCE").and_return("1")

    expect { task.invoke(zip_path) }.to output(/integrity_check: ok/).to_stdout
    expect(entry.reload.title).to eq "唐揚げ"
    expect(entry.image.download).to eq "png-bytes"
  end

  it "production では止まる" do
    entry = create(:entry, title: "唐揚げ")
    entry.image.attach(io: StringIO.new("png-bytes"), filename: "karaage.png", content_type: "image/png")
    image = entry.image.blob.service.path_for(entry.image.blob.key)
    zip_task.invoke(zip_path)
    entry.update!(title: "改ざん")
    File.binwrite(image, "tampered")

    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    expect { task.invoke(zip_path) }.to raise_error(SystemExit).and output(/development と test 以外/).to_stderr
    allow(Rails).to receive(:env).and_call_original
    expect(entry.reload.title).to eq "改ざん"
    expect(File.binread(image)).to eq "tampered"
  end

  it "zip slip を拒否する" do
    entry = create(:entry, title: "唐揚げ")
    outside = Rails.root.join("tmp/backup-restore-slip-#{Process.pid}.txt")
    FileUtils.rm_f(outside)

    [
      "../tmp/#{outside.basename}",
      "active_storage/test/../../tmp/#{outside.basename}",
      "db/../../tmp/#{outside.basename}"
    ].each do |name|
      FileUtils.rm_f(zip_path)
      Zip::File.open(zip_path, create: true) do |zip|
        zip.get_output_stream(name) { |io| io.write("pwned") }
      end

      expect { task.invoke(zip_path) }.to raise_error(SystemExit).and output(/想定外のエントリ/).to_stderr
      task.reenable
    end

    absolute = File.join(dir, "absolute.zip")
    write_stored_zip(absolute, { "/tmp/#{outside.basename}" => "pwned" })
    expect { task.invoke(absolute) }.to raise_error(SystemExit).and output(/想定外のエントリ/).to_stderr

    expect(outside).not_to exist
    expect(entry.reload.title).to eq "唐揚げ"
  end

  it "checksum が一致しないと終了コードが 0 以外になる" do
    entry = create(:entry, title: "唐揚げ")
    entry.image.attach(io: StringIO.new("png-bytes"), filename: "karaage.png", content_type: "image/png")
    key = entry.image.blob.key
    zip_task.invoke(zip_path)

    tampered = File.join(dir, "tampered.png")
    File.binwrite(tampered, "tampered")
    Zip::File.open(zip_path) { |zip| zip.replace(storage_entry(key), tampered) }

    with_empty_destination do
      expect { task.invoke(zip_path) }.to raise_error(SystemExit) { |error|
        expect(error.status).to eq 1
      }.and output(/checksum が一致しない blob: 1 件（#{key}）/).to_stderr
    end
  end

  it "ファイルが欠けていると終了コードが 0 以外になる" do
    entry = create(:entry, title: "唐揚げ")
    entry.image.attach(io: StringIO.new("png-bytes"), filename: "karaage.png", content_type: "image/png")
    key = entry.image.blob.key
    zip_task.invoke(zip_path)
    Zip::File.open(zip_path) { |zip| zip.remove(storage_entry(key)) }

    with_empty_destination do
      expect { task.invoke(zip_path) }.to raise_error(SystemExit) { |error|
        expect(error.status).to eq 1
      }.and output(/ファイルが見つからない blob: 1 件（#{key}）/).to_stderr
    end
  end
end
