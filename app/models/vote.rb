class Vote < ApplicationRecord
  include Votable

  belongs_to :entry

  delegate :event, :category, to: :entry

  scope :in_category, ->(event, category) {
    joins(:entry).where(entries: { event_id: event, category_id: category })
  }
  scope :cast_by, ->(user, event, category) { in_category(event, category).where(user_id: user) }

  def self.remaining_for(user, event, category)
    MAX_VOTES_PER_CATEGORY - cast_by(user, event, category).count
  end

  private

  def vote_target
    entry
  end

  def votes_in_same_category
    Vote.cast_by(user_id, entry.event_id, entry.category_id)
  end

  def votes_for_same_target
    Vote.where(user_id: user_id, entry_id: entry_id)
  end
end
