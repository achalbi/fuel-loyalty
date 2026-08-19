class Customer < ApplicationRecord
  PHONE_NUMBER_LENGTH = 10
  PHONE_NUMBER_FORMAT = /\A\d{#{PHONE_NUMBER_LENGTH}}\z/
  PHONE_NUMBER_ERROR_MESSAGE = "must be a 10 digit number"

  has_many :transactions, dependent: :restrict_with_exception
  has_many :points_ledgers, dependent: :destroy
  has_many :vehicles, -> { order(:vehicle_number) }, dependent: :destroy
  has_many :customer_contacts, dependent: :destroy
  has_many :customer_notes, -> { recent_first }, dependent: :destroy, inverse_of: :customer
  has_many :contact_logs, dependent: :destroy
  has_many :customer_feedbacks, dependent: :destroy
  has_many :visit_entries, dependent: :nullify
  has_many :push_subscriptions, dependent: :nullify
  has_many :notification_recipients, dependent: :nullify

  # Which notification channels this customer can currently be reached on.
  def reachable_channels
    channels = []
    channels << "push" if push_subscriptions.active.exists?
    channels << "whatsapp" if whatsapp_opt_in? && phone_number.present?
    channels << "sms" if sms_opt_in? && phone_number.present?
    channels
  end
  belongs_to :primary_contact, class_name: "CustomerContact", optional: true
  # A contact row only persists if it carries a name or phone — a role picked on
  # an otherwise-empty row is treated as an untouched blank and dropped.
  accepts_nested_attributes_for :customer_contacts, allow_destroy: true,
    reject_if: ->(attrs) { attrs["name"].blank? && attrs["phone_number"].blank? }

  # E4 — account-type segmentation (OTP = fleet/credit account, drive-in = walk-in
  # cash, credit = credit account). Backfilled to drive_in for existing rows.
  CUSTOMER_TYPES = { drive_in: "drive_in", otp: "otp", credit: "credit" }.freeze
  # Wording and display order fixed by FSM staff: Drive-In, Credit, Fleet/OTP.
  # Every picker, filter chip and badge reads from here so the three types are
  # named identically on web, API and the app.
  CUSTOMER_TYPE_LABELS = { "drive_in" => "Drive-In", "credit" => "Credit", "otp" => "Fleet/OTP" }.freeze
  enum :customer_type, CUSTOMER_TYPES, default: :drive_in

  def self.customer_type_label_for(code)
    CUSTOMER_TYPE_LABELS.fetch(code.to_s) { code.to_s.humanize }
  end

  # [label, value] pairs for select/options helpers, in the staff-facing order.
  def self.customer_type_options
    CUSTOMER_TYPE_LABELS.map { |code, label| [label, code] }
  end

  def customer_type_label
    self.class.customer_type_label_for(customer_type)
  end

  # Customers who recorded a transaction within the given time range (E2 dashboard
  # drill-through). Uses a subquery so it composes with joins + distinct scopes.
  scope :active, -> { where(active: true) }
  scope :transacted_between, ->(range) { where(id: Transaction.where(created_at: range).select(:customer_id)) }

  # A "visit" is either a loyalty transaction OR a captured visit_entry — unioned
  # so neither the loyalty-only (drive-in) nor the visit-only (fleet/OTP/credit)
  # segment is dropped from cadence (E3) and churn (E6). `range` is a Time range
  # (from OverviewReport.period_range); visit_entries compare on their entry_date.
  scope :visited_between, ->(range) {
    txn = Transaction.where(created_at: range).select(:customer_id)
    visits = VisitEntry.where(entry_date: range.begin.to_date..range.end.to_date)
                       .where.not(customer_id: nil).select(:customer_id)
    where(id: txn).or(where(id: visits))
  }

  # Item 13 — notes are an append-only log (see CustomerNote), but the create and
  # update paths on all three surfaces write a single `info_note` field. Keep
  # that spelling: assigning it queues a new dated entry instead of overwriting
  # the last one, and reading it returns the most recent entry so existing
  # views and API payloads keep showing "the note".
  attr_accessor :info_note_author

  def info_note=(value)
    @pending_note = value.to_s.strip.presence
  end

  def info_note
    return @pending_note if defined?(@pending_note) && @pending_note.present?

    latest_note&.body
  end

  def latest_note
    customer_notes.loaded? ? customer_notes.max_by(&:created_at) : customer_notes.recent_first.first
  end

  after_save :append_pending_note

  def append_pending_note
    note = @pending_note
    @pending_note = nil
    return if note.blank?
    # Re-saving a record without touching the field must not duplicate the entry.
    return if latest_note&.body == note

    customer_notes.create!(body: note, author: info_note_author)
  end

  before_validation :normalize_phone_number

  # A contact may be added before we know their name; phone number is the
  # required identity for the outreach/customer directory.
  validates :name, length: { maximum: 255 }, allow_blank: true
  validates :phone_number, presence: true, uniqueness: true
  validates :phone_number, format: { with: PHONE_NUMBER_FORMAT, message: PHONE_NUMBER_ERROR_MESSAGE }
  # Per-contact uniqueness only checks the DB; this catches two *new* rows with
  # the same phone submitted together (nested attributes) before they hit the
  # [customer_id, phone_number] index as a 500.
  validate :customer_contact_phones_are_distinct
  validate :pending_note_within_length

  # The note is written by an after_save callback, so check its length up front
  # rather than letting CustomerNote raise mid-transaction.
  def pending_note_within_length
    return if @pending_note.blank? || @pending_note.length <= 2000

    errors.add(:info_note, "is too long (maximum is 2000 characters)")
  end

  def customer_contact_phones_are_distinct
    phones = customer_contacts.reject(&:marked_for_destruction?)
                              .map { |contact| self.class.normalize_phone_number(contact.phone_number).presence }
                              .compact
    repeated = phones.tally.select { |_phone, count| count > 1 }.keys
    return if repeated.empty?

    errors.add(:base, "A contact phone number is used more than once (#{repeated.join(', ')}). Each contact needs a distinct phone.")
  end

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
