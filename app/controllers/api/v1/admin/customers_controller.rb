module Api
  module V1
    module Admin
      # E3/E5 — per-customer CRM insight (cadence, recency, conversion probability,
      # contact + feedback rollups). Admin-only. Customer CRUD itself lives under the
      # staff API; this namespace holds the admin-only analytics read.
      class CustomersController < Api::V1::Admin::BaseController
        def insight
          authorize :dashboard, :show?
          customer = Customer.find(params[:id])
          insight = ::Admin::Crm::CustomerInsight.new(customer)
          render json: CustomerInsightSerializer.call(insight), status: :ok
        end
      end
    end
  end
end
