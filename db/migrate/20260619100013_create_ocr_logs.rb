class CreateOcrLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :ocr_logs do |t|
      t.references :record, polymorphic: true, null: false
      t.string     :filename
      t.string     :status, null: false, default: "processing"
      t.datetime   :started_at, null: false
      t.datetime   :completed_at
      t.float      :duration
      t.text       :error_message
      t.timestamps
    end
  end
end
