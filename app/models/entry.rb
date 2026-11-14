class Entry < ApplicationRecord
  HEIF_CONTENT_TYPES = %w[image/heic image/heif].freeze
  IMAGE_CONTENT_TYPES = (%w[image/jpeg image/png] + HEIF_CONTENT_TYPES).freeze
  IMAGE_MAX_SIZE = 5.megabytes
  IMAGE_MAX_COUNT = 5

  belongs_to :user
  belongs_to :event
  belongs_to :category

  has_many :votes, dependent: :destroy
  # 既存の添付データをそのまま読めるよう、保存時の添付名は image を使う。
  has_many_attached :image do |attachment|
    attachment.variant :display, format: :jpeg, resize_to_limit: [ 1600, 1600 ]
  end

  validates :title, presence: true
  validates :description, length: { maximum: 300 }
  validate :category_must_not_be_talk
  validate :validate_images, if: -> { attachment_changes.key?("image") }

  def display_images
    image.sort_by(&:id).map do |attachment|
      HEIF_CONTENT_TYPES.include?(attachment.content_type) ? attachment.variant(:display) : attachment
    end
  end

  private

  def category_must_not_be_talk
    errors.add(:category, :not_allowed_for_entry) if category&.talk?
  end

  def validate_images
    errors.add(:image, :too_many, max: IMAGE_MAX_COUNT) if image.size > IMAGE_MAX_COUNT
    if image.blobs.any? { |blob| !IMAGE_CONTENT_TYPES.include?(blob.content_type) }
      errors.add(:image, :invalid_content_type)
    end
    if image.blobs.any? { |blob| blob.byte_size > IMAGE_MAX_SIZE }
      errors.add(:image, :too_large, max: IMAGE_MAX_SIZE / 1.megabyte)
    end
  end
end
