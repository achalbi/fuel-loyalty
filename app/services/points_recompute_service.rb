class PointsRecomputeService
  # D9 ⇄ C5. When an admin edit changes a settlement discount line that is linked
  # (through its B2 visit entry) to a loyalty transaction, propagate the new
  # discount to that transaction's derived ₹ and reverse+re-award its earn points
  # — all inside the caller's DB transaction so the whole edit is atomic. Returns
  # true if any customer's points were recomputed.
  #
  # Only the discount-line → transaction path is propagated: a settlement's other
  # lines (nozzle readings, lubes, credit) are reconciliation figures that no
  # customer's transaction derives from, so editing them never rewrites loyalty.
  def self.call(...) = new(...).call

  def initialize(settlement, diffs)
    @settlement = settlement
    @diffs = diffs
  end

  def call
    return false unless @diffs.key?("discount_lines")

    recomputed = false
    @settlement.discount_lines.reject(&:marked_for_destruction?).each do |line|
      transaction = line.visit_entry&.fuel_transaction
      next if transaction.nil? || transaction.vehicle.nil?

      recomputed = true if recompute_transaction!(transaction, line.discount_amount.to_d)
    end
    recomputed
  end

  private

  def recompute_transaction!(transaction, new_discount)
    return false if new_discount == transaction.discount_amount.to_d

    gross = transaction.gross_amount.presence || (transaction.fuel_amount.to_d + transaction.discount_amount.to_d)
    new_net = [gross.to_d - new_discount, 0].max

    transaction.update!(discount_amount: new_discount, fuel_amount: new_net)
    reaward_points!(transaction, new_net)
    true
  end

  def reaward_points!(transaction, new_net)
    earn = transaction.customer.points_ledgers.find_by(fuel_transaction: transaction, entry_type: :earn)
    return if earn.nil? # rewards were paused at capture; nothing was awarded

    points =
      if rewards_paused?(transaction.customer)
        0
      else
        PointsCalculator.call(
          new_net,
          fuel_type: transaction.vehicle.fuel_type,
          vehicle_kind: transaction.vehicle.vehicle_kind,
          litres: transaction.litres
        )
      end

    earn.update!(points: points)
  end

  def rewards_paused?(customer)
    customer.rewards_paused? || RewardSetting.current.rewards_paused?
  end
end
