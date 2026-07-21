class CustomerContact < ApplicationRecord
  # B1 — a driver / supervisor / owner / manager for a customer, with a
  # "contacted-by" marker (contacted + contacted_at) and an info note.
  ROLES = %w[driver supervisor owner manager].freeze

  belongs_to :customer

  before_validation :normalize_fields
  before_save :stamp_contacted_at

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :phone_number,
    format: { with: Customer::PHONE_NUMBER_FORMAT, message: Customer::PHONE_NUMBER_ERROR_MESSAGE },
    allow_blank: true
  validates :contacted, inclusion: { in: [true, false] }

  scope :active, -> { where(active: true) }

  def display_role
    role.to_s.humanize
  end

  private

  def normalize_fields
    self.role = role.to_s.strip.downcase.presence
    self.name = name.to_s.squish.presence
    self.phone_number = Customer.normalize_phone_number(phone_number).presence
  end

  def stamp_contacted_at
    if contacted?
      self.contacted_at ||= Time.current
    else
      self.contacted_at = nil
    end
  end
end
