class Entry < ApplicationRecord
  HEIF_CONTENT_TYPES = %w[image/heic image/heif].freeze
  IMAGE_CONTENT_TYPES = (%w[image/jpeg image/png] + HEIF_CONTENT_TYPES).freeze
  IMAGE_MAX_SIZE = 5.megabytes
  IMAGE_MAX_COUNT = 5

  belongs_to :user
  belongs_to :event
  belongs_to :category

  has_many :votes, dependent: :destroy
  has_many_attached :images do |attachment|
    attachment.variant :display, format: :jpeg, resize_to_limit: [ 1600, 1600 ]
  end

  validates :title, presence: true
  validates :description, length: { maximum: 300 }
  validate :category_must_not_be_talk
  validate :validate_images

  def display_images
    images.sort_by(&:id).map do |attachment|
      HEIF_CONTENT_TYPES.include?(attachment.content_type) ? attachment.variant(:display) : attachment
    end
  end

  private

  def category_must_not_be_talk
    errors.add(:category, :not_allowed_for_entry) if category&.talk?
  end

  def validate_images
    errors.add(:images, :too_many, max: IMAGE_MAX_COUNT) if images.size > IMAGE_MAX_COUNT
    if images.blobs.any? { |blob| !IMAGE_CONTENT_TYPES.include?(blob.content_type) }
      errors.add(:images, :invalid_content_type)
    end
    if images.blobs.any? { |blob| blob.byte_size > IMAGE_MAX_SIZE }
      errors.add(:images, :too_large, max: IMAGE_MAX_SIZE / 1.megabyte)
    end
  end
end
