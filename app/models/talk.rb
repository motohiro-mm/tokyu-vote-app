# LT王の候補。登壇者は投票アプリにログインしないため users とは紐づけない。
class Talk < ApplicationRecord
  enum :status, { scheduled: 0, canceled: 1 }, validate: true

  belongs_to :event

  has_many :talk_votes, dependent: :destroy

  # 除外する状態ではなく許可する状態を列挙する。
  # 将来「保留」のような状態を足したときに、自動で投票対象から外れるため
  scope :votable, -> { where(status: :scheduled) }

  validates :user_name, presence: true
  validates :title, presence: true
  before_validation :normalize_slide_url

  validates :description, length: { maximum: 300 }
  validates :slide_url, length: { maximum: 2048 }
  validate :slide_url_is_valid
  validate :status_changeable_only_before_voting, if: :status_changed?

  def self.status_label(status)
    I18n.t("enums.talk.status.#{status}")
  end

  def status_label
    self.class.status_label(status)
  end

  def safe_slide_url
    return if slide_url.blank?

    uri = URI.parse(slide_url)
    slide_url if %w[http https].include?(uri.scheme) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  private

  def normalize_slide_url
    self.slide_url = slide_url&.strip.presence
  end

  def slide_url_is_valid
    errors.add(:slide_url, :invalid_url) if slide_url.present? && safe_slide_url.nil?
  end

  # 票が入った後のキャンセルは票の扱いが決まっていないため、投票開始前しか認めない
  def status_changeable_only_before_voting
    return if new_record?
    return if event&.preparing?

    errors.add(:status, :not_allowed_after_voting_started)
  end
end
