class CreateConstraints < ActiveRecord::Migration[8.0]
  def change
    create_table :constraints do |t|
      t.references :student, null: false, foreign_key: true
      t.string :constraint_type, null: false
      t.text :constraint_value
      t.text :description
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :constraints, [ :student_id, :constraint_type ]
  end
end
