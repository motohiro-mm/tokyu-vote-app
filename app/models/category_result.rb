# 管理画面・参加者向けの結果画面・静的書き出しで同じ内容を出すため、1イベント × 1部門の結果をここで組み立てる。
class CategoryResult
  # 結果画面に並べる投票対象。Entry と Talk で持っている項目が違うため揃えて渡す
  Target = Data.define(:title, :name, :image, :comments)

  attr_reader :event, :category

  def initialize(event, category)
    @event = event
    @category = category
  end

  def rankings
    # LT王は登壇者を users と紐づけていないため合算王を出せず、単品王と書き分ける必要もない
    return [ [ category.label, TalkVote.ranking(event) ] ] if category.talk?

    [
      [ "#{category.label}（単品王）", Vote.ranking_by_entry(event, category) ],
      [ "#{category.label}（合算王）", Vote.ranking_by_user(event, category) ]
    ]
  end

  # コメントの無い候補は出さない（参考リポジトリと同じ。「コメントはありません」と並べると寂しいため）
  def targets
    (category.talk? ? talk_targets : entry_targets).select { |target| target.comments.any? }
  end

  private

  def entry_targets
    comments = comments_by(Vote.in_category(event, category), :entry_id)

    event.entries.where(category: category).includes(:user).with_attached_image.order(:id).map do |entry|
      Target.new(
        title: entry.title,
        name: entry.user.name,
        image: (entry.image if entry.image.attached?),
        comments: comments.fetch(entry.id, [])
      )
    end
  end

  def talk_targets
    comments = comments_by(TalkVote.in_event(event), :talk_id)

    event.talks.votable.order(:id).map do |talk|
      Target.new(title: talk.title, name: talk.user_name, image: nil, comments: comments.fetch(talk.id, []))
    end
  end

  # 誰が書いたかは出さないため、コメント本文だけを対象ごとにまとめる
  def comments_by(votes, target_key)
    votes.order(:id).pluck(target_key, :comment)
         .select { |_target_id, comment| comment.present? }
         .group_by(&:first)
         .transform_values { |pairs| pairs.map(&:last) }
  end
end
