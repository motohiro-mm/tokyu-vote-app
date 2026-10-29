class RemoveRedundantIndexes < ActiveRecord::Migration[8.1]
  def change
    # 同じ先頭列を持つ複合インデックスで検索できるため、単独の索引を削除する。
    remove_index :votes, :user_id
    remove_index :talk_votes, :user_id
    remove_index :talks, :event_id
  end
end
