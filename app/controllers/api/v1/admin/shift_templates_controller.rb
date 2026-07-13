module Api
  module V1
    module Admin
      # Admin shift-template CRUD (mirrors web Admin::ShiftTemplatesController).
      # duration_hours is a virtual write attribute that drives duration_minutes.
      class ShiftTemplatesController < Api::V1::Admin::BaseController
        # GET /api/v1/admin/shift_templates
        def index
          authorize ShiftTemplate, :index?
          shift_templates = ShiftTemplate.order(:name, :duration_minutes)
          render json: {
            shift_templates: shift_templates.map { |shift_template| ShiftTemplateSerializer.call(shift_template) },
          }, status: :ok
        end

        # POST /api/v1/admin/shift_templates
        # { shift_template: { name, start_time, duration_hours | duration_minutes, active } }
        def create
          shift_template = ShiftTemplate.new
          authorize shift_template, :create?
          shift_template.assign_attributes(shift_template_params)
          shift_template.save!
          render json: ShiftTemplateSerializer.call(shift_template), status: :created
        end

        # PATCH /api/v1/admin/shift_templates/:id
        def update
          shift_template = ShiftTemplate.find(params[:id])
          authorize shift_template, :update?
          shift_template.update!(shift_template_params)
          render json: ShiftTemplateSerializer.call(shift_template), status: :ok
        end

        private

        def shift_template_params
          resource_params(:shift_template).permit(:name, :start_time, :duration_hours, :duration_minutes, :active)
        end
      end
    end
  end
end
