class OtpChallengesController < ApplicationController
  allow_unauthenticated_access
  before_action :require_pending_user
  rate_limit to: 5, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if @user.verify_otp(params[:code])
      clear_pending
      start_new_session_for @user
      redirect_to after_authentication_url
    else
      redirect_to new_otp_challenge_path, alert: "Invalid code."
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
      unless @user&.otp_enabled?
        clear_pending
        redirect_to new_session_path
      end
    end

    def clear_pending
      session.delete(:pending_user_id)
      session.delete(:pending_at)
    end
end
