class Entry < ApplicationRecord
  HEIF_CONTENT_TYPES = %w[image/heic image/heif].freeze
  IMAGE_CONTENT_TYPES = (%w[image/jpeg image/png] + HEIF_CONTENT_TYPES).freeze
  IMAGE_MAX_SIZE = 5.megabytes
  IMAGE_MAX_COUNT = 5

  IMAGE_SIZES = {
    display: { resize_to_limit: [ 1600, 1600 ] },
    # 一覧の表示は 96px だが、高解像度の画面でぼやけないよう倍の大きさで作る
    thumbnail: { resize_to_fill: [ 192, 192 ] }
  }.freeze

  belongs_to :user
  belongs_to :event
  belongs_to :category

  has_many :votes, dependent: :destroy
  has_many_attached :images do |attachment|
    IMAGE_SIZES.each do |size, transformations|
      # スマホの写真には撮影場所（GPS）などが入っているため、縮小版を作るときにメタデータを消す
      options = transformations.merge(saver: { strip: true })
      # JPEG・PNG は形式を変えない（PNG の透過を残すため）。HEIF は多くのブラウザで表示できないので JPEG にする
      attachment.variant size, **options
      attachment.variant :"#{size}_jpeg", **options, format: :jpeg
    end
  end

  validates :title, presence: true
  validates :description, length: { maximum: 300 }
  validate :category_must_not_be_talk
  validate :validate_images

  def display_images(size = :display)
    images.sort_by(&:id).map do |attachment|
      variant_name = HEIF_CONTENT_TYPES.include?(attachment.content_type) ? :"#{size}_jpeg" : size
      attachment.variant(variant_name)
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
