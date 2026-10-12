class AddOtpLastUsedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_last_used_at, :bigint
  end
end
