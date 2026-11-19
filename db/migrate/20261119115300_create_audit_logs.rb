class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.string :event, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :detail
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, :created_at
    add_index :audit_logs, :event
  end
end
