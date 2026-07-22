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

        # E6 — lost-customer / reach-out list for the selected period.
        def churn
          authorize :dashboard, :show?

          report = ::Admin::Crm::ChurnReport.new(
            preset: params[:preset], start_date: params[:start_date], end_date: params[:end_date],
            page: params[:page], per_page: params[:per_page] || ::Admin::Crm::ChurnReport::DEFAULT_PER_PAGE
          )
          render json: report.as_json, status: :ok
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
