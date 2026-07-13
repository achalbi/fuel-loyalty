module Api
  module V1
    module Admin
      # Admin CRUD for FuelType (JSON mirror of the web Admin::FuelTypesController;
      # docs/native-handoff/backend-map/subsystem-controllers-admin-catalogs.md).
      #
      # `code` is never accepted from the client: the model auto-generates it from
      # `name` on the first save and leaves it fixed thereafter. Destroy is guarded
      # by model `before_destroy` callbacks (throw :abort) when vehicles or pump
      # nozzles still reference the fuel type -> surfaced as 409.
      class FuelTypesController < Api::V1::Admin::BaseController
        before_action :set_fuel_type, only: %i[update destroy]

        # GET /api/v1/admin/fuel_types
        def index
          authorize FuelType, :index?
          fuel_types = FuelType.for_settings
          render json: { fuel_types: fuel_types.map { |ft| FuelTypeSerializer.call(ft) } }, status: :ok
        end

        # POST /api/v1/admin/fuel_types  { name, active }
        def create
          authorize FuelType, :create?
          attrs = resource_params(:fuel_type)
          fuel_type = FuelType.new
          fuel_type.name = attrs[:name] if attrs.key?(:name)
          fuel_type.active = attrs[:active] if attrs.key?(:active)
          fuel_type.save!
          render json: FuelTypeSerializer.call(fuel_type), status: :created
        end

        # PATCH/PUT /api/v1/admin/fuel_types/:id  { name, active }
        def update
          authorize @fuel_type, :update?
          attrs = resource_params(:fuel_type)
          @fuel_type.name = attrs[:name] if attrs.key?(:name)
          @fuel_type.active = attrs[:active] if attrs.key?(:active)
          @fuel_type.save!
          render json: FuelTypeSerializer.call(@fuel_type), status: :ok
        end

        # DELETE /api/v1/admin/fuel_types/:id
        def destroy
          authorize @fuel_type, :destroy?
          if @fuel_type.destroy
            render json: { id: @fuel_type.id, message: "Fuel type removed successfully." }, status: :ok
          else
            render_error(status: :conflict, code: "delete_restricted",
                         message: @fuel_type.errors.full_messages.to_sentence.presence ||
                                  "This fuel type cannot be removed.")
          end
        end

        private

        def set_fuel_type
          @fuel_type = FuelType.find(params[:id])
        end
      end
    end
  end
end
