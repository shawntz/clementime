class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: 'ta'
      t.boolean :is_active, default: true
      t.string :first_name
      t.string :last_name
      t.boolean :must_change_password, default: true

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :email, unique: true
  end
end
