class Entry < ApplicationRecord
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif].freeze

  belongs_to :user
  belongs_to :event
  belongs_to :category

  has_many :votes, dependent: :destroy
  has_one_attached :image

  validates :title, presence: true
  validates :description, length: { maximum: 300 }
  validate :category_must_not_be_talk
  validate :image_must_be_supported_format

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
end
