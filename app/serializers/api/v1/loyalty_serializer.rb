module Api
  module V1
    # The public loyalty-result payload (docs/native-handoff/05). Mirrors the
    # fields the web result page renders; the client owns presentation
    # (count-up, status copy, localization).
    class LoyaltySerializer
      def self.call(customer, full_history: false)
        total = customer.total_points
        minimum = customer.minimum_redeemable_points
        max_redeemable = customer.max_redeemable_points
        activities = customer.loyalty_activities(limit: full_history ? nil : 5)

        {
          customer: {
            name: customer.display_name,
            phone_number: customer.phone_number,
          },
          total_points: total,
          rewards_paused: customer.rewards_paused?,
          minimum_redeemable_points: minimum,
          max_redeemable_points: max_redeemable,
          points_until_redeemable: customer.points_until_redeemable,
          rewards_unlocked: max_redeemable >= minimum,
          full_history: full_history,
          show_full_history: !full_history && customer.loyalty_activities_count > 5,
          activities: activities.map { |entry| activity_json(entry) },
        }
      end

      def self.activity_json(entry)
        transaction = entry.fuel_transaction
        vehicle = transaction&.vehicle
        {
          id: entry.id,
          entry_type: entry.entry_type, # "earn" | "redeem"
          points: entry.points, # signed: earn +, redeem -
          created_at: entry.created_at.iso8601,
          fuel_type: vehicle&.fuel_type,
          vehicle_number: vehicle&.vehicle_number,
          fuel_amount: transaction&.fuel_amount&.to_f,
        }
      end
    end
  end
end
