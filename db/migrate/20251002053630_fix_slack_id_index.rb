class FixSlackIdIndex < ActiveRecord::Migration[8.0]
  def up
    # Remove any existing slack_id indexes
    remove_index :users, :slack_id if index_exists?(:users, :slack_id)
    remove_index :users, :slack_id, name: "index_users_on_slack_id" if index_exists?(:users, :slack_id, name: "index_users_on_slack_id")

    # Add a simple non-unique index
    add_index :users, :slack_id unless index_exists?(:users, :slack_id)
  end

  def down
    remove_index :users, :slack_id if index_exists?(:users, :slack_id)
  end
end
