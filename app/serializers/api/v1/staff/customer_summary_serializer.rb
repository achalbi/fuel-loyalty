module Api
  module V1
    module Staff
      # Compact customer row for the staff customers list.
      class CustomerSummarySerializer
        def self.call(customer)
          {
            id: customer.id,
            name: customer.display_name,
            phone_number: customer.phone_number,
            active: customer.active?,
            rewards_paused: customer.rewards_paused?,
            total_points: customer.total_points,
            vehicle_numbers: customer.vehicles.map(&:vehicle_number),
            vehicles_count: customer.vehicles.size,
          }
        end
      end
    end
  end
end
