# 投票画面の詳細は投票のための画面なので、結果からは順位とコメントを添えた別の画面で見せる
class Entries::ResultsController < ApplicationController
  include EventScoped
  include ResultsPublished

  def show
    @entry = @event.entries.includes(:category, :user).with_attached_images.find(params[:entry_id])
    @category = @entry.category
    result = CategoryResult.new(@event, @category)
    @placements = result.placements(@entry.id)
    @comments = result.comments_for(@entry.id)
  end
end
