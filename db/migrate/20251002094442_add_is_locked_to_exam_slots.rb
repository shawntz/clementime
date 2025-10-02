class AddIsLockedToExamSlots < ActiveRecord::Migration[8.0]
  def change
    add_column :exam_slots, :is_locked, :boolean, default: false, null: false
  end
end
