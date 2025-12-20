class AddSectionOverrideToStudents < ActiveRecord::Migration[8.0]
  def change
    add_column :students, :section_override, :boolean, default: false, null: false
  end
end
