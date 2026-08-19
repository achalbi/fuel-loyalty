module CounterEntry
  # Item 2 — the single counter capture. Staff asked for "only one way to
  # capture the transaction or the customer", so New Transaction and Capture
  # Visit became one screen. One submit writes both records:
  #
  #   * a VisitEntry — litres (the source of truth, LOCKED Q1), the driver /
  #     transport / Fleet-OTP detail, and the discount the D3 settlement pull
  #     reads; and
  #   * a Transaction — the ₹ and the points ledger (C5).
  #
  # Neither downstream pipeline loses its source, and neither surface has to
  # know which record feeds which report. VisitEntryRecorder does the writing;
  # this module owns the field list the two surfaces post and the decision of
  # which records are possible for a given capture.
  module_function

  Result = Struct.new(
    :visit_entry, :transaction, :customer, :points_earned, :rewards_paused, :visit_skipped_reason,
    keyword_init: true
  )

  # Lookup and fuel fields (the old transaction form) plus the visit detail (the
  # old capture form). Shared by the web controller and the JSON API so the two
  # cannot drift.
  TRANSACTION_FIELDS = %i[
    lookup_mode phone_number vehicle_number vehicle_id customer_id
    fuel_amount litres discount_amount fuel_pump_id fuel_pump_nozzle_id payment_mode
  ].freeze

  VISIT_FIELDS = %i[
    entry_date fuel_type_code fleet_otp transport_name approx_vehicle_count
    driver_name driver_phone_number manager_name manager_phone_number
    owner_name owner_phone_number
  ].freeze

  PERMITTED_FIELDS = (TRANSACTION_FIELDS + VISIT_FIELDS).freeze

  NO_PRICE_REASON = "No catalog selling price for this fuel, so only the sale was recorded — " \
                    "set the price in Products to capture visits too.".freeze

  def record(user:, params:)
    attributes = params.to_h.symbolize_keys
    vehicle = resolve_vehicle(attributes)
    litres = resolvable_litres(attributes, vehicle)

    # A visit is keyed by litres and a plate. Without a catalog price there is
    # nothing to convert a typed ₹ into, and without a plate there is nothing to
    # key on — record the sale rather than blocking the counter, and say why the
    # visit was skipped.
    return transaction_only(user, attributes, NO_PRICE_REASON) if litres.blank?

    record_pair(user, attributes, vehicle, litres)
  end

  # --- paths -----------------------------------------------------------------

  def record_pair(user, attributes, vehicle, litres)
    result = VisitEntryRecorder.call(
      user: user,
      attributes: visit_attributes(attributes, vehicle, litres),
      # A walk-in whose plate we don't know yet has no customer to award points
      # to; the visit is still worth recording.
      create_transaction: vehicle.present?,
      fuel_pump_nozzle_id: attributes[:fuel_pump_nozzle_id],
      payment_mode: attributes[:payment_mode],
      fuel_amount: attributes[:fuel_amount]
    )

    Result.new(
      visit_entry: result.visit_entry,
      transaction: result.transaction,
      customer: result.visit_entry.customer,
      points_earned: result.points_earned,
      rewards_paused: result.rewards_paused
    )
  end

  # TransactionCreator resolves the customer itself, so it takes the lookup
  # fields rather than a customer_id.
  CREATOR_FIELDS = (TRANSACTION_FIELDS - %i[customer_id]).freeze

  def transaction_only(user, attributes, reason)
    creator_args = attributes.slice(*CREATOR_FIELDS)
    creator_args[:vehicle_id] ||= nil
    result = TransactionCreator.call(user: user, **creator_args)

    Result.new(
      visit_entry: nil,
      transaction: result.transaction,
      customer: result.customer,
      points_earned: result.points_earned,
      rewards_paused: result.rewards_paused,
      visit_skipped_reason: reason
    )
  end

  # --- resolution ------------------------------------------------------------

  def visit_attributes(attributes, vehicle, litres)
    attributes
      .slice(*(VISIT_FIELDS + %i[vehicle_id customer_id discount_amount fuel_pump_id]))
      .merge(
        litres: litres,
        # The phone-lookup path picks a vehicle from the customer's list and
        # posts only its id, but a visit is keyed by the plate — fill it in.
        vehicle_number: attributes[:vehicle_number].presence || vehicle&.vehicle_number
      )
  end

  def resolve_vehicle(attributes)
    return Vehicle.find_by(id: attributes[:vehicle_id]) if attributes[:vehicle_id].present?
    return nil if attributes[:vehicle_number].blank?

    Vehicle.find_by(vehicle_number: Vehicle.normalize_vehicle_number(attributes[:vehicle_number]))
  end

  # Litres as typed, or converted from the ₹ the meter showed at the catalog
  # price. nil means neither was available.
  def resolvable_litres(attributes, vehicle)
    typed = attributes[:litres].presence&.to_d
    return typed if typed&.positive?

    gross = attributes[:fuel_amount].presence&.to_d
    return nil if gross.nil? || !gross.positive?

    price = FuelPricing.current_price(attributes[:fuel_type_code].presence || vehicle&.fuel_type)
    return nil if price.blank? || price.to_d.zero?

    (gross / price.to_d).round(3)
  end
end
