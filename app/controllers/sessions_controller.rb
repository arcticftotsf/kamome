class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

def create
  if user = User.authenticate_by(params.permit(:email_address, :password))
    if user.otp_enabled?
      # コード確認が終わるまで、ログイン済みにはしない
      session[:pending_user_id] = user.id
      session[:pending_at] = Time.current.to_i
      redirect_to new_otp_challenge_path
    else
      start_new_session_for user
      redirect_to after_authentication_url
    end
  else
    redirect_to new_session_path, alert: "Try another email address or password."
  end
end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
