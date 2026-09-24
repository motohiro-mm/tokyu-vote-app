# 飯王・酒王への投票。
class Vote < ApplicationRecord
  include Votable

  belongs_to :entry

  delegate :event, :category, to: :entry

  private

  def vote_target
    entry
  end

  def votes_in_same_category
    Vote.joins(:entry).where(
      user_id: user_id,
      entries: { event_id: entry.event_id, category_id: entry.category_id }
    )
  end

  def votes_for_same_target
    Vote.where(user_id: user_id, entry_id: entry_id)
  end
end
