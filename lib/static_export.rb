require "fileutils"

# 書き出した HTML は Rails なしで表示されるため、リンクもアセットもすべて相対パスにする。
class StaticExport
  def initialize(out_dir)
    @out = Pathname(out_dir)
  end

  def run
    FileUtils.rm_rf(@out)
    FileUtils.mkdir_p(@out)

    events = Event.closed.order(:id).to_a
    categories = Category.order(:id).to_a

    write_page("index.html", "exports/index", events: events)
    events.each do |event|
      write_page("events/#{event.id}/index.html", "exports/event", event: event, categories: categories)
      categories.each do |category|
        result = CategoryResult.new(event, category)
        write_page("events/#{event.id}/#{category.category_name}.html", "exports/category",
                   event: event, category: category, result: result)
        copy_images(result)
      end
    end
    copy_assets
    write_noindex_headers if staging?

    Dir[@out.join("**/*")].count { |path| File.file?(path) }
  end

  # 書き出し先での画像の置き場所。ビューとファイルのコピーで同じ場所を指すようここに集める
  def self.image_path(image)
    "images/#{image.blob.key}.#{image.blob.content_type.delete_prefix("image/")}"
  end

  private

  def write_page(path, template, assigns)
    file = @out.join(path)
    FileUtils.mkdir_p(file.dirname)
    root = "../" * path.count("/")
    File.write(file, renderer.render(template: template, layout: "export", assigns: assigns.merge(root: root)))
  end

  def renderer
    @renderer ||= ApplicationController.renderer
  end

  def copy_images(result)
    result.targets.filter_map(&:image).each do |image|
      file = @out.join(self.class.image_path(image))
      FileUtils.mkdir_p(file.dirname)
      File.binwrite(file, image.download)
    end
  end

  # ダイジェスト付きのファイル名は Rails がないと解決できないため、素の名前で置く
  def copy_assets
    FileUtils.mkdir_p(@out.join("assets"))
    Rails.application.assets.load_path.assets.each do |asset|
      next unless asset.logical_path.extname == ".css"

      File.write(@out.join("assets", asset.logical_path), asset.content)
    end
    %w[icon.png icon.svg].each { |name| FileUtils.cp(Rails.public_path.join(name), @out.join(name)) }
  end

  # リハーサル用に公開したサイトが検索に載らないようにする
  def write_noindex_headers
    File.write(@out.join("_headers"), "/*\n  X-Robots-Tag: noindex, nofollow\n")
  end

  def staging?
    ENV["APP_ENV_LABEL"] == "staging"
  end
end
