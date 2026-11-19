class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  def readonly?
    persisted? || super
  end

  def self.record(event, user: nil, request: nil, detail: nil)
    create!(
      event: event,
      user: user,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent.to_s.truncate(255),
      detail: detail&.to_s&.truncate(255)
    )
  rescue => e
    # 必ず痕跡は残す
    Rails.logger.error("AuditLog failed: #{e.class}: #{e.message}")
  end
end
