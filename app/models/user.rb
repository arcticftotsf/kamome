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


  MAX_FAILED_LOGINS = 5
  FAILURE_WINDOW = 1.hour

  def locked?
    locked_at.present?
  end

  # このミスでロックされたら :locked を返す
  def register_failed_login!
    return :already_locked if locked?

    # 最後のミスから1時間以上空いていたら、数え直す
    if last_failed_login_at.nil? || last_failed_login_at < FAILURE_WINDOW.ago
      update_columns(failed_login_count: 0)
    end

    User.where(id: id).update_all(
      [ "failed_login_count = failed_login_count + 1, last_failed_login_at = ?", Time.current ]
    )
    reload

    if failed_login_count >= MAX_FAILED_LOGINS
      lock!
      :locked
    else
      :counted
    end
  end

  def lock!
    update_columns(locked_at: Time.current)
    sessions.destroy_all   # ロックしたら、ログイン中の端末もすべて切る
  end

  def unlock!
    update_columns(locked_at: nil, failed_login_count: 0, last_failed_login_at: nil)
  end

  def reset_failed_logins!
    update_columns(failed_login_count: 0) if failed_login_count.positive?
  end
end
