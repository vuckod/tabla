# frozen_string_literal: true

class AddUnitToUsersAndDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :enota, :string
    add_index :users, :enota

    add_column :documents, :unit, :integer, default: 0, null: false
    add_index :documents, :unit
  end
end
