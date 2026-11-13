class AddDescriptionToTalks < ActiveRecord::Migration[8.1]
  def change
    add_column :talks, :description, :text
  end
end
