class VotesController < ApplicationController
  include EventScoped

  before_action :require_open_event, only: :create

  def categories
    @categories = Category.order(:id)
  end

  def create
    entry = @event.entries.find(vote_params[:entry_id])
    vote = current_user.votes.build(entry: entry, comment: vote_params[:comment])

    # 同じユーザーの投票を直列化する。ロックのあとで残票と重複を読み直してから保存する。
    # count < 3 だけだと、別の対象への同時 POST が 3 票を超えられる。
    current_user.with_lock do
      vote.save!
    end

    redirect_to event_votes_completions_path(@event, category: entry.category.category_name)
  rescue ActiveRecord::RecordInvalid
    redirect_to_entry_with_alert(entry, vote)
  rescue ActiveRecord::RecordNotUnique
    # バリデーションを抜けたあとにユニークインデックスへ当たったときは 500 にしない
    vote.errors.add(:base, :already_voted)
    redirect_to_entry_with_alert(entry, vote)
  end

  # LT王の完了画面は talk_votes#completions が持つ。
  # ここで talk を受け付けると、残票を votes から数えて 404 への導線を出してしまう
  def completions
    @category = Category.for_entries.find_by_name!(params[:category])
    @remaining_votes = Vote.remaining_for(current_user, @event, @category)
  end

  private

  def vote_params
    params.expect(vote: [ :entry_id, :comment ])
  end

  def redirect_to_entry_with_alert(entry, vote)
    redirect_to event_entry_path(@event, entry, category: entry.category.category_name),
                alert: vote.errors.full_messages.to_sentence
  end
end
