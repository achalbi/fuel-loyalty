class Customer < ApplicationRecord
  PHONE_NUMBER_LENGTH = 10
  PHONE_NUMBER_FORMAT = /\A\d{#{PHONE_NUMBER_LENGTH}}\z/
  PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit number"

  has_many :transactions, dependent: :restrict_with_exception
  has_many :points_ledgers, dependent: :destroy
  has_many :vehicles, -> { order(:vehicle_number) }, dependent: :destroy

  before_validation :normalize_phone_number

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

  def total_points
    return self[:total_points_sum].to_i if has_attribute?(:total_points_sum)

    points_ledgers.sum(:points)
  end

  def recent_transactions(limit = 5)
    transactions.includes(:vehicle, :user).order(created_at: :desc).limit(limit)
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
end
