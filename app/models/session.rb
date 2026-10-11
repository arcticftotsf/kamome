class Session < ApplicationRecord
  belongs_to :user

  IDLE_TIMEOUT     = 5.minutes
  ABSOLUTE_TIMEOUT = 8.hours

  scope :expired, -> {
    where("updated_at < ? OR created_at < ?", IDLE_TIMEOUT.ago, ABSOLUTE_TIMEOUT.ago)
  }

  def expired?
    updated_at < IDLE_TIMEOUT.ago || created_at < ABSOLUTE_TIMEOUT.ago
  end
end
