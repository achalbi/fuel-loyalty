module Admin
  class DashboardController < BaseController
    def show
      authorize :dashboard, :show?
      report = dashboard_report
      @dashboard_filters = report.filters
      @dashboard_payload = report.as_json
    end

    def data
      authorize :dashboard, :show?

      render json: dashboard_report.as_json
    end

    private

    def dashboard_report
      @dashboard_report ||= Admin::Dashboard::OverviewReport.new(
        start_date: params[:start_date],
        end_date: params[:end_date],
        segment: params[:segment],
        preset: params[:preset],
        fuel_type: params[:fuel_type]
      )
    end
  end
end
