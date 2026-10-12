class TwoFactorsController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: %i[create destroy],
             with: -> { redirect_to two_factor_path, alert: "Try again later." }

  def show
    user = Current.user
    return if user.otp_enabled?

    # 未有効の間だけ秘密鍵を用意する(再読み込みしても同じQRが出る)
    user.update!(otp_secret: ROTP::Base32.random) if user.otp_secret.blank?
    uri = totp(user).provisioning_uri(user.email_address)
    @qr_svg = RQRCode::QRCode.new(uri).as_svg(module_size: 4, standalone: true,
                                              use_path: true, viewbox: true)
  end

  def create
    user = Current.user
    if user.verify_otp(params[:code])
      user.update!(otp_enabled: true)
      flash[:backup_codes] = user.regenerate_backup_codes!
      redirect_to backup_codes_path
    else
      redirect_to two_factor_path, alert: "Invalid code."
    end
  end

  def destroy
    user = Current.user
    if user.authenticate(params[:password].to_s)
      user.update!(otp_enabled: false, otp_secret: nil, otp_last_used_at: nil)
      user.backup_codes.delete_all
      redirect_to two_factor_path, notice: "Two-factor authentication disabled."
    else
      redirect_to two_factor_path, alert: "Wrong password."
    end
  end

  private
    def totp(user)
      ROTP::TOTP.new(user.otp_secret, issuer: "kamome")
    end
end
