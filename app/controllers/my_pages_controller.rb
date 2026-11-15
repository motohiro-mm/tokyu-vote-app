class MyPagesController < ApplicationController
  def show
    no_store

    entry_votes = current_user.votes.includes(entry: [ :event, :category, :user ]).order(:id).map do |vote|
      entry_item(vote.entry).merge(name: vote.entry.user.name, comment: vote.comment)
    end
    talk_votes = current_user.talk_votes.includes(talk: :event).order(:id).map do |vote|
      talk = vote.talk
      event = talk.event
      path = event_talk_path(event, talk) if details_available?(event) && talk.scheduled?

      { event: event, category: I18n.t("enums.category.category_name.talk"), title: talk.title,
        name: talk.user_name, comment: vote.comment, path: path }
    end

    @votes_by_event = group_by_event(entry_votes + talk_votes)
    @entries_by_event = group_by_event(current_user.entries.includes(:event, :category).order(:id).map { |entry| entry_item(entry) })
  end

  private

  def entry_item(entry)
    event = entry.event
    category = entry.category
    path = event_entry_path(event, entry, category: category.category_name) if details_available?(event)

    { event: event, category: category.label, title: entry.title, path: path }
  end

  def details_available?(event)
    event.open? || event.results_published?
  end

  def group_by_event(items)
    items.group_by { |item| item.fetch(:event) }.sort_by { |event, _| [ event.created_at, event.id ] }.reverse
  end
end
