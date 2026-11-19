class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    attempted = User.find_by(email_address: params[:email_address])
    user = User.authenticate_by(params.permit(:email_address, :password))

    if user&.locked?
      AuditLog.record("login_blocked", user: user, request: request)
      deny_login
    elsif user
      if user.otp_enabled?
        session[:pending_user_id] = user.id
        session[:pending_at] = Time.current.to_i
        AuditLog.record("password_ok", user: user, request: request)
        redirect_to new_otp_challenge_path
      else
        user.reset_failed_logins!
        start_new_session_for user
        AuditLog.record("login_success", user: user, request: request)
        redirect_to after_authentication_url
      end
    else
      if attempted
        result = attempted.register_failed_login!
        AuditLog.record("login_failed", user: attempted, request: request)
        AuditLog.record("account_locked", user: attempted, request: request) if result == :locked
      else
        # 入力されたメールは記録しない(パスワードを打ち間違えて入れてしまうことがあるため)
        AuditLog.record("login_failed_unknown_user", request: request)
      end
      deny_login
    end
  end

  def destroy
    AuditLog.record("logout", user: Current.user, request: request)
    terminate_session
    redirect_to new_session_path
  end

  private
  def deny_login
    redirect_to new_session_path, alert: "Try another email address or password."
  end
end
