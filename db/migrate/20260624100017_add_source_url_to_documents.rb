# frozen_string_literal: true

class AddSourceUrlToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :source_url, :string
    add_index :documents, :source_url, unique: true, where: "source_url IS NOT NULL"
  end
end
