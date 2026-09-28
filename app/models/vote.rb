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

  def self.ranking_by_entry(event, category)
    counts = in_category(event, category).group(:entry_id).count

    ranked(Entry.where(id: counts.keys).includes(:user).map { |entry|
      { id: entry.id, name: entry.user.name, title: entry.title, vote_count: counts.fetch(entry.id) }
    })
  end

  def self.ranking_by_user(event, category)
    counts = in_category(event, category).group("entries.user_id").count

    ranked(User.where(id: counts.keys).map { |user|
      { id: user.id, name: user.name, title: nil, vote_count: counts.fetch(user.id) }
    })
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
