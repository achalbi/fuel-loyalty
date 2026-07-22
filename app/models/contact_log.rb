class ContactLog < ApplicationRecord
  # E5 — one recorded outreach attempt against a customer. Distinct from
  # CustomerContact (B1), which is the *roster* of people; a ContactLog is an
  # *event*: staff U reached person P on channel C with outcome O at time T.
  CHANNELS = %w[call whatsapp sms in_person].freeze
  # Outcomes ordered from best to worst for the E5 conversion heuristic.
  OUTCOMES = %w[converted reached callback_requested no_answer declined].freeze

  belongs_to :customer
  belongs_to :user
  # The B1 person reached, when the log was tied to a specific contact.
  belongs_to :customer_contact, optional: true

  before_validation :normalize_fields
  before_validation :default_contacted_at, on: :create

  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validates :outcome, presence: true, inclusion: { in: OUTCOMES }
  validates :contacted_role, inclusion: { in: CustomerContact::ROLES }, allow_blank: true
  validates :contacted_at, presence: true
  validate :contacted_at_not_in_future

  scope :recent_first, -> { order(contacted_at: :desc, id: :desc) }

  def channel_label
    channel.to_s.humanize
  end

  def outcome_label
    outcome.to_s.humanize
  end

  private

  def normalize_fields
    self.channel = channel.to_s.strip.downcase.presence
    self.outcome = outcome.to_s.strip.downcase.presence
    self.contacted_role = contacted_role.to_s.strip.downcase.presence
  end

  def default_contacted_at
    self.contacted_at ||= Time.current
  end

  def contacted_at_not_in_future
    return if contacted_at.blank?

    errors.add(:contacted_at, "cannot be in the future") if contacted_at > Time.current + 1.minute
  end
end
