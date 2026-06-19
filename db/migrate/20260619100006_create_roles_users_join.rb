class CreateRolesUsersJoin < ActiveRecord::Migration[8.1]
  def change
    create_join_table :roles, :users do |t|
      t.index [:user_id, :role_id], unique: true
      t.index [:role_id, :user_id]
    end
  end
end
