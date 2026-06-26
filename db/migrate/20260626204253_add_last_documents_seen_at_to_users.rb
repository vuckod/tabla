# frozen_string_literal: true

class AddLastDocumentsSeenAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_documents_seen_at, :datetime

    reversible do |dir|
      dir.up do
        execute "UPDATE users SET last_documents_seen_at = NOW() WHERE last_documents_seen_at IS NULL"
      end
    end
  end
end
