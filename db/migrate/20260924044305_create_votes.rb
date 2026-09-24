class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true
      t.text :comment

      t.timestamps
    end

    # 同時リクエストでの二重投票をモデルのバリデーションだけに任せないため
    add_index :votes, [ :user_id, :entry_id ], unique: true
  end
end
