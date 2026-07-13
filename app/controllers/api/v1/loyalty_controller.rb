module Api
  module V1
    # POST /api/v1/loyalty/lookup  { phone_number, full_history }
    #
    # Direct JSON replacement for the web token round-trip (docs/native-handoff/05).
    # Returns the customer's balance, redemption status, and recent loyalty
    # activity. Public and unauthenticated — abuse protection (rate limiting) is
    # a documented follow-up (docs/native-handoff/12).
    class LoyaltyController < Api::V1::PublicController
      def lookup
        attrs = resource_params(:loyalty)
        phone = Customer.normalize_phone_number(attrs[:phone_number])

        unless Customer.valid_phone_number?(phone)
          return render_error(status: 422, code: "invalid_phone",
                              message: "Phone number must be a 10 digit number.")
        end

        customer = Customer.find_by(phone_number: phone)
        if customer.nil?
          return render_error(status: :not_found, code: "customer_not_found",
                              message: "No customer found for that phone number.")
        end

        full_history = ActiveModel::Type::Boolean.new.cast(attrs[:full_history]) || false
        render json: Api::V1::LoyaltySerializer.call(customer, full_history:), status: :ok
      end
    end
  end
end
