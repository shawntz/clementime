class CreateRecordings < ActiveRecord::Migration[8.0]
  def change
    create_table :recordings do |t|
      t.references :exam_slot, null: false, foreign_key: true, index: { unique: true }
      t.references :section, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.references :ta, null: false, foreign_key: { to_table: :users }
      t.string :recording_url
      t.string :google_drive_file_id
      t.datetime :recorded_at
      t.datetime :uploaded_at

      t.timestamps
    end

  end
end
