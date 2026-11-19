class ActiveSessionsController < ApplicationController
  def index
    @sessions = Current.user.sessions.active.order(updated_at: :desc)
  end

  def destroy
    target = Current.user.sessions.find(params[:id])
    if target == Current.session
      redirect_to active_sessions_path, alert: "Use Sign out to end this session."
    else
      target.destroy
      redirect_to active_sessions_path, notice: "Session ended."
    end
  end

  def others
    Current.user.sessions.where.not(id: Current.session.id).destroy_all
    redirect_to active_sessions_path, notice: "All other sessions ended."
  end
end
