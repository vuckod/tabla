class CreateDocumentCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :document_categories do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.integer :position, default: 0
      t.string  :color
      t.text    :description
      t.timestamps
    end

    add_index :document_categories, :name, unique: true
    add_index :document_categories, :slug, unique: true
  end
end
