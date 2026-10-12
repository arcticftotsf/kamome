class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :todos, dependent: :destroy
  encrypts :otp_secret

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
          format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true

  def verify_otp(code)
    return false if otp_secret.blank?

    totp = ROTP::TOTP.new(otp_secret, issuer: "kamome")
    timestamp = totp.verify(code.to_s.strip, drift_behind: 15, after: otp_last_used_at)
    return false unless timestamp

    # 同時に2回送られても1回しか通らないよう、DB側で更新
    User.where(id: id)
        .where("otp_last_used_at IS NULL OR otp_last_used_at < ?", timestamp)
        .update_all(otp_last_used_at: timestamp) == 1
  end
end
