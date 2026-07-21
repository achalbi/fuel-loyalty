class VisitEntryRecorder
  # B2 — records an FSM per-visit capture: resolves the customer/vehicle from the
  # plate (or explicit ids), defaults the pump to the caller's My Pump, upserts
  # the driver/manager/owner contacts, and — when asked — links a loyalty
  # transaction via the unchanged TransactionCreator (litres path).
  Result = Struct.new(:visit_entry, :transaction, :points_earned, keyword_init: true)

  # A visit-entry column set the recorder assigns directly.
  DIRECT_ATTRS = %i[
    entry_date vehicle_number driver_name driver_phone_number litres fuel_type_code
    discount_amount fleet_otp transport_name manager_name manager_phone_number
    owner_name owner_phone_number approx_vehicle_count
  ].freeze

  UPSERT_ROLES = {
    "driver" => %i[driver_name driver_phone_number],
    "manager" => %i[manager_name manager_phone_number],
    "owner" => %i[owner_name owner_phone_number],
  }.freeze

  def self.call(...) = new(...).call

  def initialize(user:, attributes:, create_transaction: false, fuel_pump_nozzle_id: nil)
    @user = user
    @attributes = attributes.to_h.symbolize_keys
    @create_transaction = ActiveModel::Type::Boolean.new.cast(create_transaction)
    @fuel_pump_nozzle_id = fuel_pump_nozzle_id
    @points_earned = nil
  end

  def call
    ActiveRecord::Base.transaction do
      visit = VisitEntry.new(@attributes.slice(*DIRECT_ATTRS))
      visit.user = @user
      resolve_customer_and_vehicle!(visit)
      visit.fuel_pump = resolve_pump!
      visit.entry_date ||= Date.current
      visit.save!
      upsert_contacts!(visit)
      link_transaction!(visit)
      Result.new(visit_entry: visit, transaction: visit.fuel_transaction, points_earned: @points_earned)
    end
  end

  private

  def resolve_customer_and_vehicle!(visit)
    vehicle = Vehicle.find_by(id: @attributes[:vehicle_id]) if @attributes[:vehicle_id].present?
    if vehicle.nil? && visit.vehicle_number.present?
      vehicle = Vehicle.find_by(vehicle_number: visit.vehicle_number)
    end

    customer = Customer.find_by(id: @attributes[:customer_id]) if @attributes[:customer_id].present?
    customer ||= vehicle&.customer

    visit.customer = customer
    visit.vehicle = vehicle
  end

  def resolve_pump!
    pump = FuelPump.active.find_by(id: @attributes[:fuel_pump_id]) if @attributes[:fuel_pump_id].present?
    pump ||= @user.transaction_fuel_pump
    return pump if pump

    invalid!("Select an active pump, or set up My Pump first.")
  end

  def invalid!(message)
    record = VisitEntry.new
    record.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, record
  end

  # Business rule 2: a captured driver/manager/owner upserts a customer_contacts
  # row (match on phone + role, else create); the first contact becomes primary.
  def upsert_contacts!(visit)
    customer = visit.customer
    return unless customer

    UPSERT_ROLES.each do |role, (name_attr, phone_attr)|
      name = visit.public_send(name_attr)
      phone = visit.public_send(phone_attr)
      next if name.blank? && phone.blank?

      upsert_contact(customer, role, name, phone)
    end

    if customer.primary_contact_id.nil? && (first = customer.customer_contacts.reorder(:id).first)
      customer.update_column(:primary_contact_id, first.id)
    end
  end

  def upsert_contact(customer, role, name, phone)
    # The DB enforces one contact per [customer_id, phone_number] (role-agnostic),
    # so a phone must be matched by phone alone — not [role, phone], which would
    # build a second row for the same phone under a different role (e.g. an
    # owner-operator whose driver phone == owner phone) and hit the unique index.
    # The earliest role wins; later captures only enrich the name.
    contact =
      if phone.present?
        customer.customer_contacts.find_or_initialize_by(phone_number: phone)
      else
        customer.customer_contacts.find_or_initialize_by(role: role, name: name)
      end
    contact.role = role if contact.new_record? || contact.role.blank?
    contact.name = name if name.present?
    contact.phone_number = phone if phone.present?
    contact.save! if contact.new_record? || contact.changed?
  end

  def link_transaction!(visit)
    return unless @create_transaction
    return if visit.customer.nil? || visit.vehicle.nil?

    result = TransactionCreator.call(
      user: @user,
      vehicle_id: visit.vehicle_id,
      litres: visit.litres,
      discount_amount: visit.discount_amount,
      fuel_pump_id: visit.fuel_pump_id,
      fuel_pump_nozzle_id: @fuel_pump_nozzle_id,
      lookup_mode: "vehicle",
      vehicle_number: visit.vehicle_number,
      payment_mode: visit.fleet_otp? ? "credit" : "cash",
    )
    visit.update!(transaction_id: result.transaction.id)
    @points_earned = result.points_earned
  end
end
