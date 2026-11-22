# 管理画面・参加者向けの結果画面・投票対象ごとの結果で同じ内容を出すため、1イベント × 1部門の結果をここで組み立てる。
class CategoryResult
  # 結果画面に並べる投票対象。Entry と Talk で持っている項目が違うため揃えて渡す
  Target = Data.define(:id, :title, :name, :image, :comments)
  # 結果画面では小さく並べ、押したら大きい写真で拡大表示するため、両方の大きさを組にして渡す
  Image = Data.define(:thumbnail, :display)
  # 画面に並べるランキングの1行。集計の行（Votable::RankingRow）に、単品王の作品を見分けるためのサムネイルを足したもの
  RankingItem = Data.define(:rank, :target_id, :name, :title, :vote_count, :entries, :thumbnail)

  attr_reader :event, :category

  def initialize(event, category)
    @event = event
    @category = category
  end

  def rankings
    # LT王は登壇者を users と紐づけていないため合算王を出せず、見出しも単品王と書き分けない
    @rankings ||= category.talk? ? [ target_ranking ] : [ target_ranking, user_ranking ]
  end

  # 公開中に管理者が集まり具合だけを確かめるための合計。誰に何票入ったかは途中経過で投票が偏るため出さない
  def vote_count
    (category.talk? ? TalkVote.in_event(event) : Vote.in_category(event, category)).count
  end

  def targets
    (category.talk? ? talk_targets : entry_targets).select { |target| target.comments.any? }
  end

  # 投票対象ごとの結果で、その作品自身の順位（単品王・LT王）を見出しと組で返す。
  # 合算王は持ち込んだ人の順位で作品の順位ではないため出さない。順位に入っていない作品の票数と順位も出さない方針のため nil を返す
  def placement(target_id)
    title, rows = target_ranking
    row = rows.find { |r| r.target_id == target_id }
    [ title, row ] if row
  end

  def comments_for(target_id)
    votes = category.talk? ? TalkVote.in_event(event).where(talk_id: target_id) : Vote.in_category(event, category).where(entry_id: target_id)
    comments_by(votes, category.talk? ? :talk_id : :entry_id).fetch(target_id, [])
  end

  private

  # 作品・LT そのものに付けた順位（単品王・LT王）。投票対象ごとの結果で出す順位はこれだけ
  def target_ranking
    @target_ranking ||= if category.talk?
      [ category.label, ranking_items(TalkVote.ranking(event)) ]
    else
      [ "#{category.label}（単品王）", ranking_items(Vote.ranking_by_entry(event, category), thumbnails: true) ]
    end
  end

  def user_ranking
    [ "#{category.label}（合算王）", ranking_items(Vote.ranking_by_user(event, category)) ]
  end

  # 単品王は作品を見分けやすいよう1枚目の写真を小さく添える。投票の集計には写真が要らないため、画面に出す行を作るここで足す
  def ranking_items(rows, thumbnails: false)
    # 集計で読み込んだ作品に写真だけを追加で読み込み、作品を読み直さない
    ActiveRecord::Associations::Preloader.new(records: rows.map(&:target), associations: { images_attachments: :blob }).call if thumbnails

    rows.map do |row|
      RankingItem.new(rank: row.rank, target_id: row.target_id, name: row.name, title: row.title, vote_count: row.vote_count,
                      entries: row.entries, thumbnail: (row.target.display_images(:thumbnail).first if thumbnails))
    end
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
