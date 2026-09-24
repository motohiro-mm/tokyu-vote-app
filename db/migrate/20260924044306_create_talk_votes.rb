class CreateTalkVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :talk_votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :talk, null: false, foreign_key: true
      t.text :comment

      t.timestamps
    end

    # 同時リクエストでの二重投票をモデルのバリデーションだけに任せないため
    add_index :talk_votes, [ :user_id, :talk_id ], unique: true
  end
end
