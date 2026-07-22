module Admin
  # E1 — the reporting page: per vehicle/transporter/driver/customer at
  # day/week/month/year grain (litres, ₹, discount, gifts, visits) with a real
  # CSV data export (distinct from the dashboard's chart screenshot).
  class ReportsController < BaseController
    def index
      authorize :dashboard, :show?
      @report = build_report
      @dimensions = ::Admin::Reports::LedgerReport::DIMENSIONS
      @grains = ::Admin::Reports::LedgerReport::GRAINS
      @fuel_types = FuelType.active.order(:name).to_a
      @fuel_pumps = FuelPump.active.ordered.to_a

      respond_to do |format|
        format.html
        format.csv do
          send_data "﻿#{@report.to_csv}",
            type: "text/csv; charset=utf-8", filename: csv_filename, disposition: "attachment"
        end
      end
    end

    private

    def build_report
      ::Admin::Reports::LedgerReport.new(
        dimension: params[:dimension], grain: params[:grain],
        start_date: params[:start_date], end_date: params[:end_date], preset: params[:preset],
        fuel_type: params[:fuel_type], fuel_pump_id: params[:fuel_pump_id]
      )
    end

    def csv_filename
      "report-#{@report.dimension}-#{@report.grain}-#{@report.date_range.begin}-#{@report.date_range.end}.csv"
    end
  end
end
