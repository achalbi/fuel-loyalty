module Api
  module V1
    module Staff
      # Vehicles nested under a customer. All actions authorize against the
      # customer's :update? (mirrors the web VehiclesController). Returns the
      # refreshed customer profile so the client can re-render in one round-trip.
      class VehiclesController < Api::V1::Staff::BaseController
        def create
          customer = Customer.find(params[:customer_id])
          authorize customer, :update?
          vehicle = customer.vehicles.new(vehicle_params)
          if vehicle.save
            render json: profile(customer), status: :created
          else
            render_validation_error(vehicle)
          end
        end

        def update
          customer = Customer.find(params[:customer_id])
          authorize customer, :update?
          vehicle = customer.vehicles.find(params[:id])
          if vehicle.update(vehicle_params)
            render json: profile(customer), status: :ok
          else
            render_validation_error(vehicle)
          end
        end

        def destroy
          customer = Customer.find(params[:customer_id])
          authorize customer, :update?
          customer.vehicles.find(params[:id]).destroy!
          render json: profile(customer), status: :ok
        rescue ActiveRecord::DeleteRestrictionError
          render_error(status: :conflict, code: "delete_restricted",
                       message: "Vehicle cannot be removed because transaction history exists.")
        end

        private

        def profile(customer)
          CustomerProfileSerializer.call(customer.reload, RewardSetting.current)
        end

        def render_validation_error(record)
          render_error(status: 422, code: "validation_failed",
                       message: record.errors.full_messages.to_sentence.presence || "Validation failed.",
                       details: record.errors.messages)
        end

        def vehicle_params
          attrs = resource_params(:vehicle)
          permitted = attrs.permit(
            :vehicle_number, :fuel_type, :vehicle_kind,
            :commercial_company_name, :commercial_contact_name,
            :commercial_contact_phone_number, :commercial_address, :commercial_notes,
          ).to_h
          if attrs.key?(:vehicle_number)
            permitted[:vehicle_number] = Vehicle.normalize_vehicle_number(attrs[:vehicle_number])
          end
          permitted
        end
      end
    end
  end
end
