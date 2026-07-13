module Api
  module V1
    module Admin
      # Admin CRUD for VehicleType (JSON mirror of the web Admin::VehicleTypesController;
      # docs/native-handoff/backend-map/subsystem-controllers-admin-catalogs.md).
      #
      # `code` is accepted on create only and is immutable on update (the update
      # whitelist omits it, matching the web `vehicle_type_update_params`).
      # `reward_points_per_100` is NOT edited here (managed by the fuel-reward-rates
      # endpoint). Destroy is guarded by the model `before_destroy` callback
      # (throw :abort) while vehicles still reference the type -> surfaced as 409.
      class VehicleTypesController < Api::V1::Admin::BaseController
        before_action :set_vehicle_type, only: %i[update destroy]

        # GET /api/v1/admin/vehicle_types
        def index
          authorize VehicleType, :index?
          vehicle_types = VehicleType.for_settings
          render json: { vehicle_types: vehicle_types.map { |vt| VehicleTypeSerializer.call(vt) } }, status: :ok
        end

        # POST /api/v1/admin/vehicle_types
        # { name, short_name, app_label_source, code, icon_name, minimum_redeemable_points, active }
        def create
          authorize VehicleType, :create?
          attrs = resource_params(:vehicle_type)
          vehicle_type = VehicleType.new
          assign_common_attributes(vehicle_type, attrs)
          vehicle_type.code = attrs[:code] if attrs.key?(:code)
          vehicle_type.save!
          render json: VehicleTypeSerializer.call(vehicle_type), status: :created
        end

        # PATCH/PUT /api/v1/admin/vehicle_types/:id
        # { name, short_name, app_label_source, icon_name, minimum_redeemable_points, active }
        # (code is immutable and ignored here.)
        def update
          authorize @vehicle_type, :update?
          assign_common_attributes(@vehicle_type, resource_params(:vehicle_type))
          @vehicle_type.save!
          render json: VehicleTypeSerializer.call(@vehicle_type), status: :ok
        end

        # DELETE /api/v1/admin/vehicle_types/:id
        def destroy
          authorize @vehicle_type, :destroy?
          if @vehicle_type.destroy
            render json: { id: @vehicle_type.id, message: "Vehicle type removed successfully." }, status: :ok
          else
            render_error(status: :conflict, code: "delete_restricted",
                         message: @vehicle_type.errors.full_messages.to_sentence.presence ||
                                  "This vehicle type cannot be removed.")
          end
        end

        private

        def set_vehicle_type
          @vehicle_type = VehicleType.find(params[:id])
        end

        # Editable attributes shared by create and update (code excluded — create
        # assigns it separately, update never touches it).
        def assign_common_attributes(vehicle_type, attrs)
          vehicle_type.name = attrs[:name] if attrs.key?(:name)
          vehicle_type.short_name = attrs[:short_name] if attrs.key?(:short_name)
          vehicle_type.app_label_source = attrs[:app_label_source] if attrs.key?(:app_label_source)
          vehicle_type.icon_name = attrs[:icon_name] if attrs.key?(:icon_name)
          vehicle_type.minimum_redeemable_points = attrs[:minimum_redeemable_points] if attrs.key?(:minimum_redeemable_points)
          vehicle_type.active = attrs[:active] if attrs.key?(:active)
        end
      end
    end
  end
end
