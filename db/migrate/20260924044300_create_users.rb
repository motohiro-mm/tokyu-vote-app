class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :name, null: false
      t.boolean :admin, null: false, default: false
      # ログイン中のセッショントークンの bcrypt ハッシュ。
      # ここを消せばサーバ側から強制ログアウトできる
      t.string :session_digest

      t.timestamps
    end

    add_index :users, [ :provider, :uid ], unique: true
  end
end
