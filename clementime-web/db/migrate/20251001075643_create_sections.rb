class CreateSections < ActiveRecord::Migration[8.0]
  def change
    create_table :sections do |t|
      t.string :code, null: false
      t.string :name
      t.string :location
      t.references :ta, foreign_key: { to_table: :users }
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :sections, :code, unique: true
  end
end
