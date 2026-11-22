class ResultsController < ApplicationController
  include EventScoped
  include ResultsPublished

  def index
    @category = Category.find_by_name!(params[:category])
    @result = CategoryResult.new(@event, @category)
  end
end
