require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # kamal-proxy が SSL を終端するので、アプリは常に SSL 経由と見なし、HTTP は HTTPS へ誘導する
  config.assume_ssl = true
  config.force_ssl = true

  # ヘルスチェック（kamal-proxy が HTTP で叩く）はリダイレクトしない
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Host ヘッダー偽装対策。ホスト名は環境ごとに違うので Kamal の env で与える。
  # APP_HOST は画面 URL の基準（1つ）。別名は APP_HOST_ALIASES（カンマ区切り）。
  # 未設定なら全ホストを許可する（ローカルで production を試すときのため）
  [ ENV["APP_HOST"], *ENV["APP_HOST_ALIASES"].to_s.split(",") ].each do |host|
    host = host.to_s.strip
    config.hosts << host if host.present?
  end

  # ヘルスチェックはホスト名無しで叩かれるので検証から除外する
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
