class CreateLinkCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :link_categories do |t|
      t.string  :name, null: false
      t.integer :position, default: 0
      t.string  :icon
      t.timestamps
    end

    add_index :link_categories, :name, unique: true
  end
end
