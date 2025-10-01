class CreateExamSlots < ActiveRecord::Migration[8.0]
  def change
    create_table :exam_slots do |t|
      t.references :student, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true
      t.integer :exam_number, null: false
      t.integer :week_number, null: false
      t.date :date
      t.time :start_time
      t.time :end_time
      t.boolean :is_scheduled, default: false

      t.timestamps
    end

    add_index :exam_slots, [ :student_id, :exam_number ], unique: true
    add_index :exam_slots, [ :section_id, :exam_number, :week_number ]
  end
end
