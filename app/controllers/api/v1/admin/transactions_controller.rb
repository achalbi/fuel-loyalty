module Api
  module V1
    module Admin
      # GET /api/v1/admin/transactions — read-only, paginated transaction list.
      # Mirrors the web Admin::TransactionsController (docs/native-handoff backend-map:
      # controllers:admin-crm): range(all|today) chip, start_date/end_date override
      # (swapped when reversed), sort, 10 per page. Filters accepted as flat query params.
      class TransactionsController < Api::V1::Admin::BaseController
        TRANSACTIONS_PER_PAGE = 10
        SORT_OPTIONS = %w[time_desc time_asc amount_desc amount_asc].freeze
        RANGE_OPTIONS = %w[all today].freeze

        def index
          authorize Transaction, :index?

          @current_start_date, @current_end_date = normalized_date_range
          @current_range = @current_start_date.present? || @current_end_date.present? ? "custom" : normalized_range
          @current_sort = normalized_sort

          scoped_transactions = filtered_transactions
          total = scoped_transactions.count
          total_pages = total.zero? ? 1 : (total.to_f / TRANSACTIONS_PER_PAGE).ceil
          page = normalized_page(total_pages)

          transactions = scoped_transactions
            .offset((page - 1) * TRANSACTIONS_PER_PAGE)
            .limit(TRANSACTIONS_PER_PAGE)

          render json: {
            transactions: transactions.map { |txn| TransactionSerializer.call(txn) },
            page: page,
            per_page: TRANSACTIONS_PER_PAGE,
            total: total,
            has_more: page * TRANSACTIONS_PER_PAGE < total,
          }, status: :ok
        end

        private

        def filtered_transactions
          scope = Transaction.includes(:customer, :fuel_pump, :user, :vehicle, fuel_pump_nozzle: %i[fuel_pump fuel_type_record])

          if @current_start_date.present? || @current_end_date.present?
            scope = scope.where("created_at >= ?", @current_start_date.beginning_of_day) if @current_start_date.present?
            scope = scope.where("created_at <= ?", @current_end_date.end_of_day) if @current_end_date.present?
          elsif @current_range == "today"
            scope = scope.where(created_at: Time.zone.today.all_day)
          end

          case @current_sort
          when "time_asc"
            scope.order(created_at: :asc, id: :asc)
          when "amount_desc"
            scope.order(fuel_amount: :desc, created_at: :desc, id: :desc)
          when "amount_asc"
            scope.order(fuel_amount: :asc, created_at: :desc, id: :desc)
          else
            scope.order(created_at: :desc, id: :desc)
          end
        end

        def normalized_range
          RANGE_OPTIONS.include?(params[:range].to_s) ? params[:range].to_s : "all"
        end

        def normalized_sort
          SORT_OPTIONS.include?(params[:sort].to_s) ? params[:sort].to_s : "time_desc"
        end

        def normalized_date_range
          start_date = parse_date(params[:start_date])
          end_date = parse_date(params[:end_date])

          if start_date.present? && end_date.present? && start_date > end_date
            [end_date, start_date]
          else
            [start_date, end_date]
          end
        end

        def normalized_page(total_pages)
          page = params[:page].to_i
          page = 1 if page < 1
          page = total_pages if page > total_pages
          page
        end

        def parse_date(value)
          return if value.blank?

          Date.iso8601(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
