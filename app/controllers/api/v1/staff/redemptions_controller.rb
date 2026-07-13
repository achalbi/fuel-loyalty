module Api
  module V1
    module Staff
      class RedemptionsController < Api::V1::Staff::BaseController
        # POST /api/v1/staff/redemptions  { phone_number, points }
        # PointsRedeemer raises ActiveRecord::RecordInvalid on any rule failure,
        # which BaseController maps to a 422 with the exact per-attribute messages.
        def create
          authorize PointsLedger, :redeem?

          attrs = resource_params(:redemption)
          result = PointsRedeemer.call(phone_number: attrs[:phone_number], points: attrs[:points])

          message = "#{result.points_redeemed} points redeemed successfully."
          if result.cash_reward_amount.present?
            message += " Cash reward: ₹#{format('%.2f', result.cash_reward_amount)}."
          end

          render json: {
            points_redeemed: result.points_redeemed,
            cash_reward_amount: result.cash_reward_amount&.to_f,
            message: message,
            customer: CustomerLookupSerializer.call(result.customer.reload, RewardSetting.current),
          }, status: :created
        end
      end
    end
  end
end
