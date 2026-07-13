module Api
  module V1
    module Admin
      # GET /api/v1/admin/dashboard
      # Analytics overview payload (summary cards, charts, rewards, filters, meta).
      # Reuses the web service Admin::Dashboard::OverviewReport verbatim; accepts the
      # same query filters: preset, start_date, end_date, segment, fuel_type.
      class DashboardController < Api::V1::Admin::BaseController
        def data
          authorize :dashboard, :show?

          render json: dashboard_report.as_json, status: :ok
        end

        private

        def dashboard_report
          @dashboard_report ||= ::Admin::Dashboard::OverviewReport.new(
            start_date: params[:start_date],
            end_date: params[:end_date],
            segment: params[:segment],
            preset: params[:preset],
            fuel_type: params[:fuel_type],
          )
        end
      end
    end
  end
end
