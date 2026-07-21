class Customer < ApplicationRecord
  PHONE_NUMBER_LENGTH = 10
  PHONE_NUMBER_FORMAT = /\A\d{#{PHONE_NUMBER_LENGTH}}\z/
  PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit number"

  has_many :transactions, dependent: :restrict_with_exception
  has_many :points_ledgers, dependent: :destroy
  has_many :vehicles, -> { order(:vehicle_number) }, dependent: :destroy

  # Customers who recorded a transaction within the given time range (E2 dashboard
  # drill-through). Uses a subquery so it composes with joins + distinct scopes.
  scope :transacted_between, ->(range) { where(id: Transaction.where(created_at: range).select(:customer_id)) }

  before_validation :normalize_phone_number

  validates :name, presence: true
  validates :phone_number, presence: true, uniqueness: true
  validates :phone_number, format: { with: PHONE_NUMBER_FORMAT, message: PHONE_NUMBER_ERROR_MESSAGE }

  def self.normalize_phone_number(value)
    value.to_s.gsub(/\D/, "")
  end

  def self.valid_phone_number?(value)
    normalize_phone_number(value).match?(PHONE_NUMBER_FORMAT)
  end

  def status_label
    active? ? "Active" : "Inactive"
  end

  def rewards_status_label
    rewards_paused? ? "Rewards Paused" : "Rewards Active"
  end

  def rewards_enabled?
    active? && !rewards_paused?
  end

  def total_points
    return self[:total_points_sum].to_i if has_attribute?(:total_points_sum)

    points_ledgers.sum(:points)
  end

  def minimum_redeemable_points
    fallback_minimum = VehicleType.minimum_redeemable_points_for_codes(registered_vehicle_type_codes)
    RewardSetting.current.effective_minimum_redeemable_points(fallback: fallback_minimum)
  end

  def max_redeemable_points
    return 0 if rewards_paused?

    reward_setting = RewardSetting.current

    PointsRedeemer.max_redeemable_points(
      total_points,
      minimum_redeemable_points: minimum_redeemable_points,
      redemption_increment: reward_setting.redemption_increment
    )
  end

  def points_until_redeemable
    [minimum_redeemable_points - total_points.to_i, 0].max
  end

  def recent_transactions(limit = 5)
    transactions
      .includes(:points_ledger, :fuel_pump, :vehicle, :user, fuel_pump_nozzle: %i[fuel_pump fuel_type_record])
      .order(created_at: :desc)
      .limit(limit)
  end

  def loyalty_activities(limit: 5)
    scope = points_ledgers
      .includes(fuel_transaction: :vehicle)
      .where(entry_type: %i[earn redeem])
      .order(created_at: :desc)

    limit ? scope.limit(limit) : scope
  end

  def loyalty_activities_count
    points_ledgers.where(entry_type: %i[earn redeem]).count
  end

  def display_name
    name.presence || "Customer"
  end

  private

  def normalize_phone_number
    self.phone_number = self.class.normalize_phone_number(phone_number)
  end

  def registered_vehicle_type_codes
    if association(:vehicles).loaded?
      vehicles.map(&:vehicle_kind)
    else
      vehicles.reorder(nil).distinct.pluck(:vehicle_kind)
    end
  end
end
