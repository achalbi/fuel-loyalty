module Api
  module V1
    module Admin
      # E3/E5 — per-customer CRM insight (cadence, recency, conversion probability,
      # contact + feedback rollups), plus the item-4 cohort list. Admin-only.
      # Customer CRUD itself lives under the staff API; this namespace holds the
      # admin-only analytics reads.
      class CustomersController < Api::V1::Admin::BaseController
        DEFAULT_PER_PAGE = 25
        MAX_PER_PAGE = 100

        # GET /api/v1/admin/customers
        # Item 4 — the threshold cohort: "customers who have visited us x times,
        # filled x litres, whom I have contacted x times, whom we have given x
        # discount, who have accumulated x reward points". Accepts the same flat
        # query params as the web filter bar (q, status, type, preset/start_date/
        # end_date, min_visits, min_litres, min_discount, min_contacts,
        # min_points_earned, min_points_balance) and returns each customer's
        # metrics alongside them so the app never has to recompute the figures.
        def index
          authorize Customer, :index?

          metrics = ::Admin::Crm::CustomerMetrics.new(range: period_range)
          thresholds = ::Admin::Crm::CustomerMetrics.thresholds_from(params)
          scope = metrics.cohort(
            query: params[:q], status: params[:status],
            customer_type: params[:type], thresholds: thresholds
          )

          total = scope.count
          total_pages = total.zero? ? 1 : (total.to_f / per_page).ceil
          page = normalized_page(total_pages)
          customers = scope
            .select("customers.*", metrics.select_sql)
            .order(created_at: :desc, id: :desc)
            .offset((page - 1) * per_page)
            .limit(per_page)
            .preload(:vehicles)
            .to_a

          render json: {
            customers: customers.map { |customer| customer_json(customer) },
            # Echoed back so the app can show what it actually filtered on after
            # the server has dropped anything blank or unparseable.
            thresholds: thresholds.transform_values { |value| value.is_a?(Integer) ? value : value.to_f },
            period: period_json,
            page: page,
            per_page: per_page,
            total: total,
            has_more: page * per_page < total,
          }, status: :ok
        end

        def insight
          authorize :dashboard, :show?
          customer = Customer.find(params[:id])
          insight = ::Admin::Crm::CustomerInsight.new(customer)
          render json: CustomerInsightSerializer.call(insight), status: :ok
        end

        private

        def customer_json(customer)
          {
            id: customer.id,
            name: customer.display_name,
            phone_number: customer.phone_number,
            customer_type: customer.customer_type,
            customer_type_label: customer.customer_type_label,
            active: customer.active?,
            vehicle_numbers: customer.vehicles.map(&:vehicle_number),
            metrics: ::Admin::Crm::CustomerMetrics.values_for(customer),
          }
        end

        def period_range
          @period_range = ::Admin::Dashboard::OverviewReport.period_range(
            preset: params[:preset], start_date: params[:start_date], end_date: params[:end_date]
          ) unless defined?(@period_range)
          @period_range
        end

        # Always the same shape (nulls when no period was asked for) so the client
        # never has to branch on a missing key.
        def period_json
          { start_date: period_range&.begin&.to_date&.iso8601, end_date: period_range&.end&.to_date&.iso8601 }
        end

        def per_page
          @per_page ||= (params[:per_page].presence || DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
        end

        def normalized_page(total_pages)
          page = params[:page].to_i
          page = 1 if page < 1
          page = total_pages if page > total_pages
          page
        end
      end
    end
  end
end
