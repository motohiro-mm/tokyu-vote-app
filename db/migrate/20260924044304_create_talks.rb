class CreateTalks < ActiveRecord::Migration[8.1]
  def change
    create_table :talks do |t|
      t.references :event, null: false, foreign_key: true
      t.string :user_name, null: false
      t.string :title, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :talks, [ :event_id, :status ]
  end
end
