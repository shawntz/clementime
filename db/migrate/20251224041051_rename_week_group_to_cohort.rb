class RenameWeekGroupToCohort < ActiveRecord::Migration[8.0]
  def change
    rename_column :students, :week_group, :cohort
  end
end
