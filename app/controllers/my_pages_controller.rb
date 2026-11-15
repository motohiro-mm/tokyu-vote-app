class MyPagesController < ApplicationController
  def show
    no_store

    entries = current_user.votes.includes(entry: [ :event, :category, :user ]).order(:id).map(&:entry)
    talks = current_user.talk_votes.includes(talk: :event).order(:id).map(&:talk)

    votes = entries.map do |entry|
      { event: entry.event, category: entry.category.label, title: entry.title, name: entry.user.name }
    end
    talks.each do |talk|
      votes << { event: talk.event, category: I18n.t("enums.category.category_name.talk"),
                 title: talk.title, name: talk.user_name }
    end

    @votes_by_event = votes.group_by { |vote| vote.fetch(:event) }
                           .sort_by { |event, _| [ event.created_at, event.id ] }.reverse
  end
end
