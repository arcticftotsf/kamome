class OtpChallengesController < ApplicationController
  allow_unauthenticated_access
  before_action :require_pending_user
  rate_limit to: 5, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    code = params[:code].to_s.strip
    numeric = code.match?(/\A\d{6}\z/)
    ok = numeric ? @user.verify_otp(code) : @user.use_backup_code(code)

    if ok
      clear_pending
      @user.reset_failed_logins!
      start_new_session_for @user
      AuditLog.record(numeric ? "login_success_2fa" : "login_success_backup_code",
                      user: @user, request: request)
      if numeric
        redirect_to after_authentication_url
      else
        redirect_to after_authentication_url,
                    notice: "Backup code used. #{@user.backup_codes_remaining} remaining."
      end
    else
      result = @user.register_failed_login!
      AuditLog.record("otp_failed", user: @user, request: request)
      if result == :locked
        AuditLog.record("account_locked", user: @user, request: request)
        clear_pending
        redirect_to new_session_path, alert: "Try another email address or password."
      else
        redirect_to new_otp_challenge_path, alert: "Invalid code."
      end
    end
  end

  private
    def require_pending_user
      id = session[:pending_user_id]
      at = session[:pending_at]

      if id.blank? || at.blank? || Time.at(at) < 5.minutes.ago
        clear_pending
        redirect_to new_session_path, alert: "Please sign in again."
        return
      end

      @user = User.find_by(id: id)
      unless @user&.otp_enabled? && !@user.locked?
        clear_pending
        redirect_to new_session_path
      end
    end

    def clear_pending
      session.delete(:pending_user_id)
      session.delete(:pending_at)
    end
end
