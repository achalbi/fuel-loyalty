class NotificationRecipient < ApplicationRecord
  # Phase 3 — a per-person, per-channel delivery record. `skipped` = no opt-in /
  # no token (never an error); `invalidated` = a dead push token deactivated.
  belongs_to :notification_message, inverse_of: :notification_recipients
  belongs_to :customer, optional: true
  belongs_to :push_subscription, optional: true

  enum :channel, { push: 0, whatsapp: 1, sms: 2 }, prefix: true
  enum :status, { pending: 0, sent: 1, failed: 2, invalidated: 3, skipped: 4 }

  scope :recent_first, -> { order(created_at: :desc) }

  def mark_sent!(provider_message_id: nil)
    update!(status: :sent, provider_message_id: provider_message_id, sent_at: Time.current)
  end

  def mark_failed!(error:, invalidated: false)
    update!(status: invalidated ? :invalidated : :failed, error: error.to_s.truncate(250))
  end

  def mark_skipped!(reason:)
    update!(status: :skipped, error: reason.to_s.truncate(250))
  end
end
