class AddLocationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :location, :string
  end
end
