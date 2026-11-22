# 管理画面・参加者向けの結果画面・投票対象ごとの結果で同じ内容を出すため、1イベント × 1部門の結果をここで組み立てる。
class CategoryResult
  # 結果画面に並べる投票対象。Entry と Talk で持っている項目が違うため揃えて渡す
  Target = Data.define(:id, :title, :name, :image, :comments)
  # 結果画面では小さく並べ、押したら大きい写真で拡大表示するため、両方の大きさを組にして渡す
  Image = Data.define(:thumbnail, :display)

  attr_reader :event, :category

  def initialize(event, category)
    @event = event
    @category = category
  end

  def rankings
    @rankings ||= if category.talk?
      # LT王は登壇者を users と紐づけていないため合算王を出せず、単品王と書き分ける必要もない
      [ [ category.label, TalkVote.ranking(event) ] ]
    else
      [
        [ "#{category.label}（単品王）", with_thumbnails(Vote.ranking_by_entry(event, category)) ],
        [ "#{category.label}（合算王）", Vote.ranking_by_user(event, category) ]
      ]
    end
  end

  # 公開中に管理者が集まり具合だけを確かめるための合計。誰に何票入ったかは途中経過で投票が偏るため出さない
  def vote_count
    (category.talk? ? TalkVote.in_event(event) : Vote.in_category(event, category)).count
  end

  def targets
    (category.talk? ? talk_targets : entry_targets).select { |target| target.comments.any? }
  end

  # 結果の詳細画面で、その作品が入った順位を部門の見出しごとに出す。合算王は持ち込んだ人の順位なので、その人の作品のどれからでも引けるようにする
  def placements(target_id)
    rankings.filter_map do |title, rows|
      row = rows.find { |r| r.target_id == target_id || r.entries.any? { |entry| entry.id == target_id } }
      [ title, row ] if row
    end
  end

  def comments_for(target_id)
    votes = category.talk? ? TalkVote.in_event(event).where(talk_id: target_id) : Vote.in_category(event, category).where(entry_id: target_id)
    comments_by(votes, category.talk? ? :talk_id : :entry_id).fetch(target_id, [])
  end

  private

  # 単品王は作品を見分けやすいよう1枚目の写真を小さく添える。投票の集計には写真が要らないため、ここで足す
  def with_thumbnails(rows)
    entries = event.entries.where(id: rows.map(&:target_id)).with_attached_images.index_by(&:id)
    rows.map { |row| row.with(thumbnail: entries.fetch(row.target_id).display_images(:thumbnail).first) }
  end

  def entry_targets
    comments = comments_by(Vote.in_category(event, category), :entry_id)

    event.entries.where(category: category).includes(:user).with_attached_images.order(:id).map do |entry|
      Target.new(
        id: entry.id,
        title: entry.title,
        name: entry.user.name,
        # 結果一覧では見分けがつけば十分なので1枚目だけを出し、ほかの写真は詳細画面で見せる
        image: entry.display_images(:thumbnail).zip(entry.display_images).first&.then { |thumbnail, display| Image.new(thumbnail:, display:) },
        comments: comments.fetch(entry.id, [])
      )
    end
  end

  def talk_targets
    comments = comments_by(TalkVote.in_event(event), :talk_id)

    event.talks.votable.order(:id).map do |talk|
      Target.new(id: talk.id, title: talk.title, name: talk.user_name, image: nil, comments: comments.fetch(talk.id, []))
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
