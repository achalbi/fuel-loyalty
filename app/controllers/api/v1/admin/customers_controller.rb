module Api
  module V1
    module Admin
      # E3/E5 — per-customer CRM insight (cadence, recency, conversion probability,
      # contact + feedback rollups, and the commercial totals: litres filled,
      # discount given, gifts given), plus the cohort list built on those same
      # figures. Admin-only. Customer CRUD itself lives under the staff API; this
      # namespace holds the admin-only analytics reads.
      class CustomersController < Api::V1::Admin::BaseController
        DEFAULT_PER_PAGE = 25
        MAX_PER_PAGE = 100

        # GET /api/v1/admin/customers
        # The cohort list: "customers who have visited us x times, filled x litres,
        # whom I have contacted x times, whom we have given x discount, who have
        # accumulated x reward points". Same flat query params as the web filter bar
        # (q, status, type, preset/start_date/end_date and the min_* thresholds) and
        # the same Admin::Crm::CustomerMetrics#cohort behind both, so the app and the
        # console cannot disagree about which customers "5 visits" returns. Each row
        # carries its own metrics so the client never recomputes them.
        def index
          authorize Customer, :index?

          thresholds = ::Admin::Crm::CustomerMetrics.normalize_thresholds(params)
          metrics = ::Admin::Crm::CustomerMetrics.new(period_range: period_range, thresholds: thresholds)
          scope = metrics.cohort(query: params[:q], status: params[:status], customer_type: params[:type])

          total = scope.count(:id)
          total_pages = total.zero? ? 1 : (total.to_f / per_page).ceil
          page = normalized_page(total_pages)
          customers = scope
            .order(created_at: :desc, id: :desc)
            .offset((page - 1) * per_page)
            .limit(per_page)
            .preload(:vehicles)

          render json: {
            customers: customers.map { |customer| customer_json(customer) },
            # Echoed back under the names they were sent, after the server has
            # dropped anything blank, negative or unparseable — so the client can
            # show what it actually filtered on rather than what it hoped it did.
            thresholds: thresholds.transform_values { |value| value.is_a?(Integer) ? value : value.to_d.to_f },
            period: period_json,
            page: page,
            per_page: per_page,
            total: total,
            has_more: page * per_page < total,
          }, status: :ok
        end

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

        # `metrics` mirrors the insight endpoint's block key for key — the same
        # CustomerMetricsDto decodes both — with `points_earned` added beside
        # `points`. `points` is the lifetime NET balance; `points_earned` is what
        # the customer earned inside the selected period. Those are the two
        # thresholds `min_points` and `min_points_earned` filter on, and a customer
        # who earned 5,000 and redeemed 4,800 reports 5,000 and 200.
        def customer_json(customer)
          {
            id: customer.id,
            name: customer.display_name,
            phone_number: customer.phone_number,
            customer_type: customer.customer_type,
            customer_type_label: customer.customer_type_label,
            active: customer.active?,
            vehicle_numbers: customer.vehicles.map(&:vehicle_number),
            metrics: {
              # Fuellings, de-duplicated on the visit-entry/transaction link — not
              # calendar days, so this count reconciles with the two sums beside it.
              visits: customer[:visit_days].to_i,
              litres: customer[:litres_filled].to_d.to_f,
              discount: customer[:discount_given].to_d.to_f,
              gifts: customer[:gifts_value].to_d.to_f,
              contacts: customer[:contact_count].to_i,
              points: customer[:total_points_sum].to_i,
              points_earned: customer[:points_earned].to_i,
            },
          }
        end

        def period_range
          return @period_range if defined?(@period_range)

          @period_range = ::Admin::Dashboard::OverviewReport.period_range(
            preset: params[:preset], start_date: params[:start_date], end_date: params[:end_date]
          )
        end

        # Always the same shape (nulls when no period was asked for) so the client
        # never has to branch on a missing key.
        def period_json
          { start_date: period_range&.begin&.to_date&.iso8601, end_date: period_range&.end&.to_date&.iso8601 }
        end

        # Blank, zero, negative and unparseable all mean "you did not ask", which is
        # the default page size — never a 1-row page from a typo.
        def per_page
          @per_page ||= begin
            requested = params[:per_page].to_i
            requested.positive? ? [requested, MAX_PER_PAGE].min : DEFAULT_PER_PAGE
          end
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
