class BackupCode < ApplicationRecord
  belongs_to :user

  def self.digest(code)
    normalized = code.to_s.downcase.gsub(/[^a-z0-9]/, "")
    key = Rails.application.key_generator.generate_key("kamome backup code")
    OpenSSL::HMAC.hexdigest("SHA256", key, normalized)
  end
end
