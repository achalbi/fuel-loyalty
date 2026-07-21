class VisitEntry < ApplicationRecord
  # B2 — the FSM per-visit CustomerDetailsEntry. See
  # docs/acefuels/13-spec-customer-crm-capture.md. Litres are the source of
  # truth (LOCKED Q1); ₹ is derived later from the catalog price. A visit may be
  # anonymous (customer/vehicle null for an unregistered plate).
  belongs_to :customer, optional: true
  belongs_to :vehicle, optional: true
  belongs_to :user
  belongs_to :fuel_pump
  # `transaction` clashes with ActiveRecord::Base#transaction, so the loyalty
  # link is exposed as `fuel_transaction` (mirrors PointsLedger).
  belongs_to :fuel_transaction, class_name: "Transaction", foreign_key: :transaction_id, optional: true

  PHONE_ATTRS = %i[driver_phone_number manager_phone_number owner_phone_number].freeze

  before_validation :normalize_fields

  validates :vehicle_number, presence: true
  validates :entry_date, presence: true
  validates :litres, numericality: { greater_than: 0 }
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }
  PHONE_ATTRS.each do |attr|
    validates attr,
      format: { with: Customer::PHONE_NUMBER_FORMAT, message: Customer::PHONE_NUMBER_ERROR_MESSAGE },
      allow_blank: true
  end

  scope :for_pump_day, ->(pump, date) { where(fuel_pump: pump, entry_date: date) }
  scope :recent_first, -> { order(created_at: :desc) }

  private

  def normalize_fields
    self.vehicle_number = Vehicle.normalize_vehicle_number(vehicle_number).presence
    PHONE_ATTRS.each do |attr|
      public_send("#{attr}=", Customer.normalize_phone_number(public_send(attr)).presence)
    end
    self.discount_amount = 0 if discount_amount.blank?
  end
end
