class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.string     :title, null: false
      t.string     :url, null: false
      t.text       :description
      t.references :link_category, null: false, foreign_key: true
      t.integer    :position, default: 0
      t.boolean    :internal_app, null: false, default: false
      t.boolean    :new_tab, null: false, default: true
      t.timestamps
    end
  end
end
