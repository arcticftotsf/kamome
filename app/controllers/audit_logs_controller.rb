class AuditLogsController < ApplicationController
  def index
    @logs = AuditLog.where(user_id: Current.user.id).order(created_at: :desc).limit(100)
  end
end
