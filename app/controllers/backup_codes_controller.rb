class BackupCodesController < ApplicationController
  before_action :require_otp_enabled
  rate_limit to: 5, within: 3.minutes, only: :create,
             with: -> { redirect_to two_factor_path, alert: "Try again later." }

  # 作った直後の1回だけ表示
  def show
    @codes = flash[:backup_codes]
    return redirect_to(two_factor_path) if @codes.blank?
    response.set_header("Cache-Control", "no-store")
  end

  # 再発行
  def create
    if Current.user.authenticate(params[:password].to_s)
      flash[:backup_codes] = Current.user.regenerate_backup_codes!
      redirect_to backup_codes_path
    else
      redirect_to two_factor_path, alert: "Wrong password."
    end
  end

  private
    def require_otp_enabled
      redirect_to two_factor_path unless Current.user.otp_enabled?
    end
end
