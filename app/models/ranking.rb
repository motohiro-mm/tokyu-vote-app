# 結果画面に出す順位表。順位を保持するテーブルは持たず、票から都度組み立てる。
class Ranking
  # 表彰するのは3位まで
  TOP_RANKS = 3

  Row = Data.define(:rank, :name, :title, :vote_count)

  class << self
    # 単品王。エントリー1件あたりの得票数で競う
    def singles(event, category)
      counts = Vote.in_category(event, category).group(:entry_id).count

      ranked(Entry.where(id: counts.keys).includes(:user).map { |entry|
        row_source(entry.id, entry.user.name, entry.title, counts.fetch(entry.id))
      })
    end

    # 合算王。同じ人が同じ部門に複数エントリーした分を合算して競う
    def totals(event, category)
      counts = Vote.in_category(event, category).group("entries.user_id").count

      ranked(User.where(id: counts.keys).map { |user|
        row_source(user.id, user.name, nil, counts.fetch(user.id))
      })
    end

    # LT王。登壇者は複数回登壇しないため単品王のみ
    def talks(event)
      counts = TalkVote.in_event(event).group(:talk_id).count

      ranked(Talk.where(id: counts.keys).map { |talk|
        row_source(talk.id, talk.user_name, talk.title, counts.fetch(talk.id))
      })
    end

    private

    def row_source(id, name, title, vote_count)
      { id: id, name: name, title: title, vote_count: vote_count }
    end

    # 同票は同じ順位にし、次の順位はその分だけ飛ばす（1位が2件なら次は3位）。
    # 3位が同票で並んだときは4件以上になっても全件載せる
    def ranked(sources)
      rank = 0
      previous_count = nil

      # 同票の並び順が実行のたびに変わらないよう、得票数の次は id で並べる
      sources.sort_by { |source| [ -source[:vote_count], source[:id] ] }
             .each_with_index
             .filter_map do |source, index|
        rank = index + 1 unless source[:vote_count] == previous_count
        previous_count = source[:vote_count]
        next if rank > TOP_RANKS

        Row.new(rank: rank, name: source[:name], title: source[:title], vote_count: source[:vote_count])
      end
    end
  end
end
