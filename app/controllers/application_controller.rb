class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # 検証環境も本番と同じ RAILS_ENV=production で動かすため、環境名ではなく
  # 専用のフラグ APP_ENV_LABEL で判定する
  before_action :require_staging_auth, if: :staging?
  before_action :set_noindex_header, if: :staging?

  before_action :require_login

  helper_method :staging?, :current_user

  private

  def staging?
    ENV["APP_ENV_LABEL"] == "staging"
  end

  # 検証環境を誤って外部に晒さないための最低限の入口制限
  def require_staging_auth
    authenticate_or_request_with_http_basic("Staging") do |_user, password|
      ActiveSupport::SecurityUtils.secure_compare(
        password, ENV.fetch("STAGING_BASIC_AUTH_PASSWORD")
      )
    end
  end

  def set_noindex_header
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_login
    return if current_user

    redirect_to login_path
  end

  def require_admin
    return if current_user&.admin?

    redirect_to root_path, alert: "管理者のみ利用できます。"
  end
end
