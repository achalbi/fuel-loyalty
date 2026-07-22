class Campaign < ApplicationRecord
  # F1 — a min-purchase-per-period reward rule, targeted and delivered as an
  # offer via the notification engine. Litres OR ₹ thresholds (both viable now
  # that D1/litres shipped). See docs/acefuels/16-spec-campaigns-notifications.md.
  CHANNELS = NotificationMessage::CHANNELS

  enum :reward_kind, { discount: 0, gift: 1, bonus_points: 2 }, prefix: :reward
  enum :period, { rolling_days: 0, weekly: 1, monthly: 2, fixed_window: 3 }, prefix: :period
  enum :target_type, { all: 0, customer_type: 1, individual: 2, selected: 3 }, prefix: :target
  enum :status, { draft: 0, scheduled: 1, active: 2, paused: 3, completed: 4 }

  belongs_to :created_by, class_name: "User", optional: true
  has_many :campaign_targets, dependent: :destroy, inverse_of: :campaign
  has_many :campaign_qualifications, dependent: :destroy, inverse_of: :campaign
  has_many :target_customers, through: :campaign_targets, source: :customer

  accepts_nested_attributes_for :campaign_targets, allow_destroy: true

  before_validation :normalize_channels

  validates :name, presence: true
  validates :channels, presence: true
  validates :period_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :bonus_points, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :discount_amount, :discount_percent, :min_purchase_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :min_purchase_litres, numericality: { greater_than: 0 }, allow_nil: true
  validate :reward_matches_kind
  validate :at_least_one_threshold
  validate :target_constraints
  validate :period_constraints

  scope :recent_first, -> { order(created_at: :desc) }

  def channel_list
    channels.to_s.split(",").map { |value| value.strip.downcase }.select { |value| CHANNELS.include?(value) }.uniq
  end

  # The purchase-aggregation window for a reference date (default today).
  def window_for(reference = Date.current)
    case period
    when "rolling_days" then (reference - (period_days.to_i - 1))..reference
    when "weekly" then reference.beginning_of_week..reference.end_of_week
    when "monthly" then reference.beginning_of_month..reference.end_of_month
    when "fixed_window" then window_start..window_end
    end
  end

  # The [start, end] that keys a qualification for idempotency. For a
  # calendar-bucket period (weekly/monthly/fixed_window) the aggregation window
  # already has a STABLE start, so re-running in the same bucket updates the same
  # row (one grant per bucket). A rolling window's start slides every day, so its
  # idempotency key is instead anchored to a fixed campaign date — one grant per
  # customer over the campaign, never a fresh grant each run day.
  def qualification_period(reference = Date.current)
    window = window_for(reference)
    return window unless period_rolling_days?

    (rolling_anchor_date..reference)
  end

  def rolling_anchor_date
    (starts_at&.to_date || created_at&.to_date || Date.current)
  end

  def thresholds_met?(amount:, litres:)
    checks = []
    checks << (amount.to_d >= min_purchase_amount) if min_purchase_amount.present?
    checks << (litres.to_d >= min_purchase_litres) if min_purchase_litres.present?
    checks.any? && checks.all?
  end

  # Structured offer rendered into the push data block + message body.
  def offer_payload
    {
      kind: reward_kind,
      discount_amount: discount_amount&.to_f,
      discount_percent: discount_percent&.to_f,
      gift_description: gift_description,
      bonus_points: bonus_points,
      expiry: ends_at&.iso8601,
    }.compact
  end

  def offer_headline
    case reward_kind
    when "discount" then discount_percent.present? ? "#{discount_percent.to_i}% off your next fill" : "₹#{discount_amount.to_i} off your next fill"
    when "gift" then gift_description.to_s
    when "bonus_points" then "#{bonus_points} bonus loyalty points"
    end
  end

  private

  def normalize_channels
    self.channels = channel_list.presence&.join(",") || "push"
  end

  def reward_matches_kind
    case reward_kind
    when "discount"
      unless discount_amount.present? ^ discount_percent.present?
        errors.add(:base, "A discount needs exactly one of amount or percent.")
      end
    when "gift"
      errors.add(:gift_description, "is required for a gift reward.") if gift_description.blank?
    when "bonus_points"
      errors.add(:bonus_points, "must be a positive number of points.") if bonus_points.to_i <= 0
    end
  end

  def at_least_one_threshold
    return if min_purchase_amount.present? || min_purchase_litres.present?

    errors.add(:base, "Set a minimum purchase amount or litres.")
  end

  def target_constraints
    case target_type
    when "customer_type"
      errors.add(:target_customer_type, "is not a known customer type.") unless Customer.customer_types.key?(target_customer_type.to_s)
    when "individual"
      errors.add(:base, "An individual campaign targets exactly one customer.") unless retained_targets.size == 1
    when "selected"
      errors.add(:base, "Select at least one customer.") if retained_targets.empty?
    end
  end

  def period_constraints
    case period
    when "rolling_days"
      errors.add(:period_days, "must be a positive number of days.") if period_days.to_i <= 0
    when "fixed_window"
      if window_start.blank? || window_end.blank?
        errors.add(:base, "A fixed window needs a start and end date.")
      elsif window_start > window_end
        errors.add(:window_end, "must not be before the start date.")
      end
    end
  end

  def retained_targets
    campaign_targets.reject(&:marked_for_destruction?)
  end
end
