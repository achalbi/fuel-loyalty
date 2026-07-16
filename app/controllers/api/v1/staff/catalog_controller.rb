module Api
  module V1
    module Staff
      # Reference data for staff-side forms. Currently powers the native app's
      # inline "add customer" flow during a transaction (an unregistered plate),
      # mirroring the web registration form's option sources: FuelType.active_options
      # and VehicleType.active_options. Vehicle kinds carry a `commercial` flag so
      # the client can show the commercial vehicle fields for lcv/mcv/hcv, matching
      # the web form's conditional block.
      class CatalogController < Api::V1::Staff::BaseController
        def show
          authorize Customer, :create?

          render json: {
            fuel_types: FuelType.active_options.map { |label, code| { code:, label: } },
            vehicle_kinds: VehicleType.active_options.map do |label, code|
              { code:, label:, commercial: Vehicle.commercial_vehicle_kind?(code) }
            end
          }, status: :ok
        end
      end
    end
  end
end
