module Api
  module V1
    module Admin
      # E3/E5 — per-customer CRM insight (cadence, recency, conversion probability,
      # contact + feedback rollups, and the commercial totals: litres filled,
      # discount given, gifts given). Admin-only. Customer CRUD itself lives under
      # the staff API; this namespace holds the admin-only analytics read.
      class CustomersController < Api::V1::Admin::BaseController
        # GET /api/v1/admin/customers/:id/insight?preset=&start_date=&end_date=
        # A period narrows the commercial totals and adds `lifetime_metrics`
        # alongside them; without one every figure is lifetime.
        def insight
          authorize :dashboard, :show?
          customer = Customer.find(params[:id])
          insight = ::Admin::Crm::CustomerInsight.new(customer, range: period_range)
          render json: CustomerInsightSerializer.call(insight), status: :ok
        end

        private

        def period_range
          ::Admin::Dashboard::OverviewReport.period_range(
            preset: params[:preset], start_date: params[:start_date], end_date: params[:end_date]
          )
        end
      end
    end
  end
end
