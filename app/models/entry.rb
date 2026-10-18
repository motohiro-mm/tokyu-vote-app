class Entry < ApplicationRecord
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png].freeze
  # スマホの高画素モード（48MP 前後）の JPEG でも 15MB に収まるため、通常の撮影を弾かずに
  # 異常に大きなファイルだけを止められる値にしている
  IMAGE_MAX_SIZE = 20.megabytes

  belongs_to :user
  belongs_to :event
  belongs_to :category

  has_many :votes, dependent: :destroy
  has_one_attached :image

  # ログインのたびに users.name は GitHub の nickname で上書きされる。
  # 飯王・酒王の過去の表示が書き換わらないよう、登録した時点の名前を残す。参加者は変更できない。
  attr_readonly :user_name

  before_validation :snapshot_user_name, on: :create

  validates :title, presence: true
  validates :user_name, presence: true
  validates :description, length: { maximum: 300 }
  validate :category_must_not_be_talk
  validate :image_must_be_supported_format
  validate :image_must_be_within_size_limit

  private

  # 渡された user_name は使わない。登録者（画面では current_user）のその時点の名前だけを写す
  def snapshot_user_name
    self.user_name = user.name if user
  end

  def category_must_not_be_talk
    errors.add(:category, :not_allowed_for_entry) if category&.talk?
  end

  def image_must_be_supported_format
    return unless image.attached?
    return if IMAGE_CONTENT_TYPES.include?(image.content_type)

    errors.add(:image, :invalid_content_type)
  end

  def image_must_be_within_size_limit
    return unless image.attached?
    return if image.byte_size <= IMAGE_MAX_SIZE

    errors.add(:image, :too_large, max: IMAGE_MAX_SIZE / 1.megabyte)
  end
end
