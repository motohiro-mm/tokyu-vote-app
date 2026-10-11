class Entry < ApplicationRecord
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif].freeze
  # スマホの高画素モード（48MP 前後）の JPEG でも 15MB に収まるため、通常の撮影を弾かずに
  # 異常に大きなファイルだけを止められる値にしている
  IMAGE_MAX_SIZE = 20.megabytes

  belongs_to :user
  belongs_to :event
  belongs_to :category

  has_many :votes, dependent: :destroy
  has_one_attached :image

  validates :title, presence: true
  validates :description, length: { maximum: 300 }
  validate :category_must_not_be_talk
  validate :image_must_be_supported_format
  validate :image_must_be_within_size_limit

  private

  # LT候補は talks が持つため、entries には LT王の部門を入れない
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
