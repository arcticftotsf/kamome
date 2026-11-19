class AddLockoutToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :failed_login_count, :integer, default: 0, null: false
    add_column :users, :last_failed_login_at, :datetime
    add_column :users, :locked_at, :datetime
  end
end
