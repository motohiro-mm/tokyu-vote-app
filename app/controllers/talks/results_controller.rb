# 投票画面の詳細は投票のための画面なので、結果からは順位とコメントを添えた別の画面で見せる
class Talks::ResultsController < ApplicationController
  include EventScoped
  include ResultsPublished

  def show
    @talk = @event.talks.votable.find(params[:talk_id])
    @category = Category.find_by_name!(:talk)
    result = CategoryResult.new(@event, @category)
    @placement = result.placement(@talk.id)
    @comments = result.comments_for(@talk.id)
  end
end
