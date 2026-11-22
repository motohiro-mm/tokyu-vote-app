class EntriesController < ApplicationController
  include EventScoped

  before_action :set_category, except: :categories
  before_action :require_open_event, only: [ :new, :create ]

  def categories
    @categories = Category.for_entries.order(:id)
  end

  def index
    @entries = @event.entries.where(category: @category).includes(:user).with_attached_images.order(:id)
    @voted_entries = Vote.cast_by(current_user, @event, @category).includes(entry: :user).map(&:entry)
    @voted_entry_ids = @voted_entries.map(&:id)
    @remaining_votes = Vote.remaining_for(current_user, @event, @category)
  end

  def show
    @entry = @event.entries.where(category: @category).with_attached_images.find(params[:id])
    @vote = Vote.new(entry: @entry)
    @cast_vote = current_user.votes.find_by(entry: @entry)
    @remaining_votes = Vote.remaining_for(current_user, @event, @category)
  end

  def new
    @entry = @event.entries.build(category: @category)
    @my_entries = my_entries
  end

  def create
    attributes = entry_params
    images = Array(attributes.delete(:images))
    # Active Storage は文字列を既存の blob の signed_id として添付する。縮小版の URL に含まれる ID を送れば
    # 他人の写真を自分のエントリーに付けられてしまうため、アップロードされたファイルだけを渡す
    uploads = thumbnail_first(images.grep(ActionDispatch::Http::UploadedFile))
    @entry = @event.entries.build(attributes.merge(images: uploads, category: @category, user: current_user))

    if @entry.valid? && image_uploads_valid?(images) && @entry.save
      redirect_to event_entries_completions_path(@event.slug, category: @category.category_name)
    else
      @my_entries = my_entries
      render :new, status: :unprocessable_entity
    end
  end

  def completions; end

  private

  # 投票一覧は先頭の画像をサムネにし、添付は渡した順に保存されるため、選ばれた画像を先頭に移す
  def thumbnail_first(images)
    index = params[:thumbnail_index].to_i
    return images unless index.between?(1, images.size - 1)

    images.dup.tap { |list| list.unshift(list.delete_at(index)) }
  end

  # フォームはファイルしか送らない（include_hidden: false）ので、ファイル以外が混ざっていれば読み込めないものとして断る
  def image_uploads_valid?(images)
    uploads = images.grep(ActionDispatch::Http::UploadedFile)
    return true if uploads.size == images.size && uploads.all? { |upload| ImageProcessing::Vips.valid_image?(upload) }

    @entry.errors.add(:images, :undecodable)
    false
  end

  def my_entries
    @event.entries.where(category: @category, user: current_user).order(:id)
  end

  def set_category
    @category = Category.for_entries.find_by_name!(params[:category])
  end

  def entry_params
    params.expect(entry: [ :title, :description, images: [] ])
  end
end
