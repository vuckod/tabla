class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.string   :title, null: false
      t.text     :body
      t.integer  :unit, null: false, default: 0
      t.datetime :published_at, null: false
      t.datetime :expires_at
      t.boolean  :pinned, null: false, default: false
      t.integer  :created_by_id
      t.integer  :updated_by_id
      t.timestamps
    end

    add_index :announcements, :published_at
    add_index :announcements, :expires_at
    add_index :announcements, :unit
  end
end
