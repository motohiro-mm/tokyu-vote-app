module ResultsHelper
  # 結果画面のランキングとコメントから、投票対象ごとの結果へリンクする。部門によって対象が作品か LT かが変わる
  def target_result_path(result, target_id)
    if result.category.talk?
      event_talk_result_path(result.event.slug, target_id)
    else
      event_entry_result_path(result.event.slug, target_id)
    end
  end
end
