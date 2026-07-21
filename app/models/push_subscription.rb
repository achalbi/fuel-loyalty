class PushSubscription < ApplicationRecord
  PLATFORMS = %w[android ios web desktop unknown].freeze

  # Optional identity so campaigns can target a customer / customer-type (F2)
  # instead of only broadcasting. Anonymous tokens leave both null.
  belongs_to :customer, optional: true
  belongs_to :user, optional: true

  scope :active, -> { where(active: true) }
  scope :for_customer, ->(customer) { where(customer: customer) }

  before_validation :normalize_token
  before_validation :normalize_platform

  validates :token, presence: true, uniqueness: true
  validates :platform, presence: true, inclusion: { in: PLATFORMS }
  validates :last_used_at, presence: true

  # `customer`/`user` are only assigned when supplied, so a later anonymous
  # re-register from the same device never clears an identity we already learned.
  def self.register!(token:, platform:, last_used_at: Time.current, customer: nil, user: nil)
    subscription = find_or_initialize_by(token: normalize_token(token))
    subscription.assign_attributes(
      platform: platform,
      last_used_at: last_used_at,
      active: true
    )
    subscription.customer = customer if customer
    subscription.user = user if user
    subscription.save!
    subscription
  end

  def deactivate!(timestamp: Time.current)
    update!(active: false, last_used_at: timestamp)
  end

  def touch_last_used!(timestamp: Time.current)
    update!(last_used_at: timestamp, active: true)
  end

  def self.normalize_token(value)
    value.to_s.strip
  end

  private

  def normalize_token
    self.token = self.class.normalize_token(token)
  end

  def normalize_platform
    normalized = platform.to_s.strip.downcase
    self.platform = normalized.presence_in(PLATFORMS) || "unknown"
  end
end
