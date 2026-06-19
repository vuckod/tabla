class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string     :title, null: false
      t.text       :description
      t.references :document_category, null: false, foreign_key: true
      t.datetime   :published_at
      t.boolean    :internal_only, null: false, default: false
      t.boolean    :notify_staff, null: false, default: false
      t.text       :ocr_text
      t.integer    :created_by_id
      t.integer    :updated_by_id
      t.timestamps
    end

    add_index :documents, :published_at
    add_index :documents, :internal_only

    # Trigram indeksi za fallback iskanje (poleg Meilisearch)
    execute "CREATE INDEX index_documents_on_title_trgm ON documents USING gin (title gin_trgm_ops)"
    execute "CREATE INDEX index_documents_on_ocr_text_trgm ON documents USING gin (ocr_text gin_trgm_ops)"
  end
end
