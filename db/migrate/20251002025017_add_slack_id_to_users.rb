class AddSlackIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :slack_id, :string
    # Note: Uniqueness is enforced at the application level for non-null values
    add_index :users, :slack_id
  end
end
