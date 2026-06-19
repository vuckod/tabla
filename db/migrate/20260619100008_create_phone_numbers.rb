class CreatePhoneNumbers < ActiveRecord::Migration[8.1]
  def change
    create_table :phone_numbers do |t|
      t.string     :number, null: false
      t.integer    :kind, null: false, default: 0   # enum: external, internal, mobile, fax
      t.string     :label
      t.references :person, foreign_key: { to_table: :persons }
      t.references :location, foreign_key: true
      t.integer    :position, default: 0
      t.timestamps
    end

    add_index :phone_numbers, :kind
  end
end
