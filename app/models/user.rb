class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :todos, dependent: :destroy
  has_many :backup_codes, dependent: :destroy
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

  def regenerate_backup_codes!
    codes = Array.new(10) { SecureRandom.alphanumeric(10).downcase }
    transaction do
      backup_codes.delete_all
      codes.each { |c| backup_codes.create!(code_digest: BackupCode.digest(c)) }
    end
    codes
  end

  def use_backup_code(input)
    BackupCode.where(user_id: id, code_digest: BackupCode.digest(input), used_at: nil)
              .update_all(used_at: Time.current) == 1
  end

  def backup_codes_remaining
    backup_codes.where(used_at: nil).count
  end
end
