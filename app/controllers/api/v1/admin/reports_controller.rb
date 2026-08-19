module Api
  module V1
    module Admin
      # E1 — reports: per vehicle/transporter/driver/customer at day/week/month/
      # year grain (litres, ₹ amount, discount, reward ₹, gift count, visits) as
      # JSON, or a CSV data export. Admin-only.
      class ReportsController < Api::V1::Admin::BaseController
        def index
          authorize :dashboard, :show?
          report = build_report

          if params[:format].to_s == "csv"
            send_data "﻿#{report.to_csv}", # UTF-8 BOM so Excel renders the ₹ glyph
              type: "text/csv; charset=utf-8", filename: csv_filename(report), disposition: "attachment"
          else
            render json: report_json(report), status: :ok
          end
        end

        private

        def build_report
          ::Admin::Reports::LedgerReport.new(
            dimension: params[:dimension], grain: params[:grain],
            start_date: params[:start_date], end_date: params[:end_date], preset: params[:preset],
            fuel_type: params[:fuel_type], fuel_pump_id: params[:fuel_pump_id],
            customer_id: params[:customer_id]
          )
        end

        def report_json(report)
          {
            dimension: report.dimension,
            grain: report.grain,
            range: { from: report.date_range.begin.iso8601, to: report.date_range.end.iso8601 },
            columns: ::Admin::Reports::LedgerReport::COLUMNS,
            # False when no ₹-per-point rate is configured: every redemption stored
            # a NULL cash value, so the client must render "—", not "₹0.00".
            reward_value_configured: report.reward_value_configured?,
            rows: report.rows.map(&:to_h),
            totals: report.totals,
          }
        end

        def csv_filename(report)
          "report-#{report.dimension}-#{report.grain}-#{report.date_range.begin}-#{report.date_range.end}.csv"
        end
      end
    end
  end
end
