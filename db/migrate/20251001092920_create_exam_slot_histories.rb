class CreateExamSlotHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :exam_slot_histories do |t|
      t.references :exam_slot, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true
      t.integer :exam_number
      t.integer :week_number
      t.date :date
      t.string :start_time
      t.string :end_time
      t.boolean :is_scheduled
      t.datetime :changed_at
      t.string :changed_by
      t.text :reason

      t.timestamps
    end
  end
end
