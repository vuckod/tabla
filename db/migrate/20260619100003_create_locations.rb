class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string  :name, null: false
      t.integer :kind, null: false, default: 0  # enum: headquarters, branch, mobile_library
      t.string  :short_code
      t.integer :position, default: 0
      t.text    :schedule_info
      t.string  :address
      t.string  :phone
      t.timestamps
    end

    add_index :locations, :name, unique: true
    add_index :locations, :kind
  end
end
