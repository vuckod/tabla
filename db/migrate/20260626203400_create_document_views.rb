# frozen_string_literal: true

class CreateDocumentViews < ActiveRecord::Migration[8.1]
  def change
    create_table :document_views do |t|
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.datetime :viewed_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :document_views, :viewed_at
    add_index :document_views, %i[user_id document_id viewed_at]
    add_index :document_views, %i[document_id viewed_at]
  end
end
