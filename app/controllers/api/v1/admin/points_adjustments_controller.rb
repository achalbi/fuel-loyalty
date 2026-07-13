module Api
  module V1
    module Admin
      # POST /api/v1/admin/points_adjustments  { phone_number, points }
      # Writes a signed `adjust` ledger entry (positive adds, negative deducts).
      # No reason field (matches the web; docs/native-handoff/07.14).
      class PointsAdjustmentsController < Api::V1::Admin::BaseController
        def create
          authorize PointsLedger, :create?

          attrs = resource_params(:points_adjustment)

          normalized = Customer.normalize_phone_number(attrs[:phone_number])
          unless Customer.valid_phone_number?(normalized)
            return render_error(status: 422, code: "invalid_phone",
                                message: "Phone number must be a 10 digit number.")
          end

          customer = Customer.find_by(phone_number: normalized)
          if customer.nil?
            return render_error(status: :not_found, code: "customer_not_found",
                                message: "Customer not found.")
          end

          points = begin
            Integer(attrs[:points].to_s.strip)
          rescue ArgumentError, TypeError
            nil
          end
          if points.nil? || points.zero?
            return render_error(status: 422, code: "invalid_points",
                                message: "Enter a non-zero whole number of points to adjust.")
          end

          customer.points_ledgers.create!(points: points, entry_type: :adjust)

          render json: {
            points_adjusted: points,
            message: "Points adjusted successfully.",
            customer: Api::V1::Staff::CustomerLookupSerializer.call(customer.reload, RewardSetting.current),
          }, status: :created
        end
      end
    end
  end
end
