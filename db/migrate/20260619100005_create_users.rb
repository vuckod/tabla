class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.integer  :remote_id, null: false   # ID iz Prisotnosti
      t.string   :username, null: false
      t.string   :ime
      t.string   :priimek
      t.string   :email
      t.boolean  :onemogocen, null: false, default: false
      t.datetime :last_synced_at
      t.datetime :last_request_at
      t.timestamps
    end

    add_index :users, :remote_id, unique: true
    add_index :users, :username, unique: true
  end
end
