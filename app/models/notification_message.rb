class NotificationMessage < ApplicationRecord
  # Phase 3 — one row per send (broadcast, targeted offer, scheduled, or loyalty
  # milestone). Fans out to notification_recipients over its channels. The
  # persistent record the ephemeral FirebasePushService::Result never was.
  CHANNELS = %w[push whatsapp sms].freeze

  belongs_to :notification_schedule, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_many :notification_recipients, dependent: :destroy, inverse_of: :notification_message

  enum :category, { broadcast: 0, offer: 1, loyalty_milestone: 2, scheduled: 3 }
  enum :target_type, { all: 0, customer_type: 1, individual: 2, selected: 3 }, prefix: :target

  validates :title, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  # The requested channels, filtered to the known set and de-duped.
  def channel_list
    channels.to_s.split(",").map { |value| value.strip.downcase }.select { |value| CHANNELS.include?(value) }.uniq
  end

  # { "push" => { sent: n, failed: n, skipped: n }, ... }
  def delivery_summary
    notification_recipients.group(:channel, :status).count.each_with_object({}) do |((channel, status), count), memo|
      (memo[channel] ||= Hash.new(0))[status] += count
    end
  end
end
