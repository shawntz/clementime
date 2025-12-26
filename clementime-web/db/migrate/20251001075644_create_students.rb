class CreateStudents < ActiveRecord::Migration[8.0]
  def change
    create_table :students do |t|
      t.string :canvas_id
      t.string :sis_user_id, null: false
      t.string :sis_login_id
      t.string :email, null: false
      t.string :full_name, null: false
      t.references :section, null: false, foreign_key: true
      t.string :week_group
      t.string :slack_user_id
      t.string :slack_username
      t.boolean :slack_matched, default: false
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :students, :email
    add_index :students, :sis_user_id, unique: true
  end
end
