class CreatePersons < ActiveRecord::Migration[8.1]
  def change
    create_table :persons do |t|
      t.string     :first_name
      t.string     :last_name, null: false
      t.string     :email
      t.string     :position_title
      t.references :location, foreign_key: true
      t.integer    :created_by_id
      t.integer    :updated_by_id
      t.boolean    :active, null: false, default: true
      t.timestamps
    end

    add_index :persons, [:last_name, :first_name]
  end
end
