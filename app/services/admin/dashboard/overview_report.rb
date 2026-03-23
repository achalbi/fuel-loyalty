module Admin
  module Dashboard
    class OverviewReport
      DEFAULT_RANGE_DAYS = 30
      QUICK_RANGES = {
        "today" => "Today",
        "this_week" => "This week",
        "this_month" => "This month",
        "last_month" => "Last month"
      }.freeze
      SEGMENTS = {
        "all" => "All customers",
        "new" => "New customers",
        "repeat" => "Repeat customers"
      }.freeze
      FUEL_TYPES = Vehicle::FUEL_TYPE_OPTIONS.each_with_object({ "all" => "Total" }) do |(label, value), options|
        options[value] = label
      end.freeze
      WEEKDAY_ORDER = {
        1 => "Mon",
        2 => "Tue",
        3 => "Wed",
        4 => "Thu",
        5 => "Fri",
        6 => "Sat",
        0 => "Sun"
      }.freeze
      LEGACY_REDEMPTION_BUCKET = :legacy_other

      def initialize(start_date:, end_date:, segment:, preset: nil, fuel_type: nil)
        @preset = QUICK_RANGES.key?(preset.to_s) ? preset.to_s : nil
        @fuel_type = FUEL_TYPES.key?(fuel_type.to_s) ? fuel_type.to_s : "all"
        @segment = SEGMENTS.key?(segment.to_s) ? segment.to_s : "all"

        if @preset.present?
          @start_date, @end_date = dates_for_preset(@preset)
        else
          @end_date = parse_date(end_date) || Time.zone.today
          @start_date = parse_date(start_date) || (@end_date - (DEFAULT_RANGE_DAYS - 1).days)
        end

        @start_date, @end_date = @end_date, @start_date if @start_date > @end_date
      end

      def as_json(*)
        {
          filters: filters,
          summary: summary_cards,
          charts: chart_payload,
          rewards: rewards_summary,
          meta: {
            range_label: "#{start_date.strftime('%d %b %Y')} - #{end_date.strftime('%d %b %Y')}",
            segment_label: SEGMENTS.fetch(segment),
            fuel_type_label: FUEL_TYPES.fetch(fuel_type),
            generated_at: Time.current.iso8601
          }
        }
      end

      def filters
        {
          start_date: start_date.iso8601,
          end_date: end_date.iso8601,
          preset: preset,
          presets: filter_presets,
          segment: segment,
          segments: SEGMENTS.map { |value, label| { value:, label: } },
          fuel_type: fuel_type,
          fuel_types: FUEL_TYPES.map { |value, label| { value:, label: } }
        }
      end

      private

      attr_reader :start_date, :end_date, :segment, :preset, :fuel_type

      def parse_date(value)
        return if value.blank?

        Date.iso8601(value)
      rescue ArgumentError
        nil
      end

      def period_length
        @period_length ||= (end_date - start_date).to_i + 1
      end

      def filter_presets
        QUICK_RANGES.map do |value, label|
          preset_start, preset_end = dates_for_preset(value)

          {
            value: value,
            label: label,
            start_date: preset_start.iso8601,
            end_date: preset_end.iso8601
          }
        end
      end

      def dates_for_preset(value)
        today = Time.zone.today

        case value
        when "today"
          [today, today]
        when "this_week"
          [today.beginning_of_week, today]
        when "this_month"
          [today.beginning_of_month, today]
        when "last_month"
          last_month = today.last_month
          [last_month.beginning_of_month, last_month.end_of_month]
        else
          [today - (DEFAULT_RANGE_DAYS - 1).days, today]
        end
      end

      def current_range
        @current_range ||= start_date.beginning_of_day..end_date.end_of_day
      end

      def previous_range
        previous_end = start_date - 1.day
        previous_start = previous_end - (period_length - 1).days

        previous_start.beginning_of_day..previous_end.end_of_day
      end

      def daily_labels
        @daily_labels ||= (start_date..end_date).map { |date| date.strftime("%d %b") }
      end

      def previous_customer_cutoff
        @previous_customer_cutoff ||= previous_range.end.to_date.end_of_day
      end

      def filtered_transactions_for(range)
        scope = Transaction.where(created_at: range)
        return scope if fuel_type == "all"

        scope.joins(:vehicle).where(vehicles: { fuel_type: fuel_type })
      end

      def transactions_for(range)
        scope = filtered_transactions_for(range)
        return scope if segment == "all"

        ids = segment_customer_ids_for(range)
        ids.empty? ? scope.none : scope.where(customer_id: ids)
      end

      def point_entries_for(range)
        scope = PointsLedger.where(created_at: range)
        if fuel_type != "all"
          scope = scope.joins(fuel_transaction: :vehicle).where(vehicles: { fuel_type: fuel_type })
        end
        return scope if segment == "all"

        ids = segment_customer_ids_for(range)
        ids.empty? ? scope.none : scope.where(customer_id: ids)
      end

      def segment_customer_ids_for(range)
        case segment
        when "new"
          new_customer_ids_for(range)
        when "repeat"
          repeat_customer_ids_for(range)
        else
          Customer.where(created_at: ..range.end).pluck(:id)
        end
      end

      def new_customer_ids_for(range)
        filtered_transactions_for(range)
          .group(:customer_id)
          .having("MIN(transactions.created_at) = (SELECT MIN(t2.created_at) FROM transactions t2 WHERE t2.customer_id = transactions.customer_id)")
          .pluck(:customer_id)
      end

      def repeat_customer_ids_for(range)
        in_range_ids = filtered_transactions_for(range).distinct.pluck(:customer_id)
        return [] if in_range_ids.empty?

        first_visits = Transaction
          .where(customer_id: in_range_ids)
          .group(:customer_id)
          .minimum(:created_at)

        first_visits.filter_map do |customer_id, first_visit_at|
          customer_id if first_visit_at < range.begin
        end
      end

      def distinct_customers_count(scope)
        scope.distinct.count(:customer_id)
      end

      def customers_total_for_range
        case segment
        when "new"
          new_customer_ids_for(current_range).count
        when "repeat"
          repeat_customer_ids_for(current_range).count
        else
          fuel_type == "all" ? Customer.where(created_at: ..current_range.end).count : distinct_customers_count(filtered_transactions_for(current_range))
        end
      end

      def customers_total_for_previous_range
        case segment
        when "new"
          new_customer_ids_for(previous_range).count
        when "repeat"
          repeat_customer_ids_for(previous_range).count
        else
          fuel_type == "all" ? Customer.where(created_at: ..previous_customer_cutoff).count : distinct_customers_count(filtered_transactions_for(previous_range))
        end
      end

      def active_customer_count
        active_range = (end_date - 29.days).beginning_of_day..end_date.end_of_day
        scope = filtered_transactions_for(active_range)
        scope = scope.where(customer_id: segment_customer_ids_for(current_range)) unless segment == "all"
        distinct_customers_count(scope)
      end

      def previous_active_customer_count
        previous_end = previous_range.end.to_date
        active_range = (previous_end - 29.days).beginning_of_day..previous_end.end_of_day
        scope = filtered_transactions_for(active_range)
        scope = scope.where(customer_id: segment_customer_ids_for(previous_range)) unless segment == "all"
        distinct_customers_count(scope)
      end

      def transactions_count(scope)
        scope.count
      end

      def revenue_total(scope)
        scope.sum(:fuel_amount).to_f
      end

      def revenue_breakdown(scope)
        grouped_revenue = scope
          .joins(:vehicle)
          .group("vehicles.fuel_type")
          .sum(:fuel_amount)

        Vehicle::FUEL_TYPE_OPTIONS.filter_map do |label, fuel_type|
          amount = grouped_revenue[fuel_type].to_f
          next if amount.zero?

          {
            key: fuel_type,
            label: label,
            value: amount.round(2),
            display_value: display_metric(amount, format: :currency)
          }
        end
      end

      def issued_points_total(scope)
        scope.where(entry_type: :earn).sum(:points).to_i
      end

      def redeemed_points_total(scope)
        scope.where(entry_type: :redeem).sum("ABS(points)").to_i
      end

      def avg_spend(total_revenue, total_transactions)
        return 0 if total_transactions.zero?

        total_revenue / total_transactions
      end

      def visits_per_customer(total_transactions, distinct_customers)
        return 0 if distinct_customers.zero?

        total_transactions.to_f / distinct_customers
      end

      def summary_cards
        current_transactions = transactions_for(current_range)
        previous_transactions = transactions_for(previous_range)
        current_points = point_entries_for(current_range)
        previous_points = point_entries_for(previous_range)

        current_total_transactions = transactions_count(current_transactions)
        previous_total_transactions = transactions_count(previous_transactions)
        current_total_revenue = revenue_total(current_transactions)
        previous_total_revenue = revenue_total(previous_transactions)
        current_revenue_breakdown = revenue_breakdown(current_transactions)
        current_points_issued = issued_points_total(current_points)
        previous_points_issued = issued_points_total(previous_points)
        current_points_redeemed = redeemed_points_total(current_points)
        previous_points_redeemed = redeemed_points_total(previous_points)
        current_distinct_customers = distinct_customers_count(current_transactions)
        previous_distinct_customers = distinct_customers_count(previous_transactions)
        current_avg_spend = avg_spend(current_total_revenue, current_total_transactions)
        previous_avg_spend = avg_spend(previous_total_revenue, previous_total_transactions)
        current_visits_per_customer = visits_per_customer(current_total_transactions, current_distinct_customers)
        previous_visits_per_customer = visits_per_customer(previous_total_transactions, previous_distinct_customers)

        [
          metric_payload("total_customers", customers_total_for_range, customers_total_for_previous_range, format: :number),
          metric_payload("active_customers", active_customer_count, previous_active_customer_count, format: :number),
          metric_payload("total_transactions", current_total_transactions, previous_total_transactions, format: :number),
          metric_payload("total_revenue", current_total_revenue, previous_total_revenue, format: :currency, breakdown: current_revenue_breakdown),
          metric_payload("points_issued", current_points_issued, previous_points_issued, format: :number),
          metric_payload("points_redeemed", current_points_redeemed, previous_points_redeemed, format: :number),
          metric_payload("avg_spend_per_visit", current_avg_spend, previous_avg_spend, format: :currency),
          metric_payload("visits_per_customer", current_visits_per_customer, previous_visits_per_customer, format: :decimal)
        ]
      end

      def metric_payload(key, current_value, previous_value, format:, breakdown: nil)
        {
          key:,
          value: current_value.round(2),
          display_value: display_metric(current_value, format:),
          change_pct: percentage_change(current_value, previous_value),
          previous_value: previous_value.round(2),
          direction: metric_direction(current_value, previous_value),
          breakdown:
        }
      end

      def display_metric(value, format:)
        case format
        when :currency
          ApplicationController.helpers.number_to_currency(value, unit: "₹", precision: value < 100 ? 2 : 0)
        when :decimal
          ApplicationController.helpers.number_with_precision(value, precision: 1, strip_insignificant_zeros: true)
        else
          ApplicationController.helpers.number_with_delimiter(value.to_i)
        end
      end

      def percentage_change(current_value, previous_value)
        return nil if previous_value.to_f.zero?

        (((current_value - previous_value) / previous_value.to_f) * 100).round(1)
      end

      def metric_direction(current_value, previous_value)
        return "neutral" if previous_value.to_f.zero? || current_value == previous_value

        current_value > previous_value ? "up" : "down"
      end

      def chart_payload
        {
          transactions_trend: line_series_for(transactions_for(current_range), value_type: :count),
          revenue_trend: line_series_for(transactions_for(current_range), value_type: :revenue),
          points_trend: points_series_for(point_entries_for(current_range)),
          active_users_trend: active_users_series_for(transactions_for(current_range)),
          repeat_vs_new: repeat_vs_new_payload,
          visits_distribution: visits_distribution_payload,
          top_customers_by_transactions: top_customers_by_transactions_payload,
          top_customers_by_revenue: top_customers_by_revenue_payload,
          top_rewards_redeemed: top_rewards_payload,
          transactions_by_hour: transactions_by_hour_payload,
          transactions_by_day: transactions_by_day_payload
        }
      end

      def line_series_for(scope, value_type:)
        grouped_values = case value_type
        when :count
          scope.group("DATE(transactions.created_at)").count
        when :revenue
          scope.group("DATE(transactions.created_at)").sum(:fuel_amount)
        end

        {
          labels: daily_labels,
          datasets: [
            {
              data: values_for_daily_series(grouped_values),
              value_type: value_type.to_s
            }
          ]
        }
      end

      def points_series_for(scope)
        issued = scope.where(entry_type: :earn).group("DATE(points_ledgers.created_at)").sum(:points)
        redeemed = scope.where(entry_type: :redeem).group("DATE(points_ledgers.created_at)").sum("ABS(points)")

        {
          labels: daily_labels,
          datasets: [
            { label: "Issued", data: values_for_daily_series(issued), value_type: "number" },
            { label: "Redeemed", data: values_for_daily_series(redeemed), value_type: "number" }
          ]
        }
      end

      def active_users_series_for(scope)
        grouped = scope.group("DATE(transactions.created_at)").distinct.count(:customer_id)

        {
          labels: daily_labels,
          datasets: [
            { data: values_for_daily_series(grouped), value_type: "number" }
          ]
        }
      end

      def repeat_vs_new_payload
        new_count = new_customer_ids_for(current_range).count
        repeat_count = repeat_customer_ids_for(current_range).count

        if segment == "new"
          repeat_count = 0
        elsif segment == "repeat"
          new_count = 0
        end

        {
          labels: ["New", "Repeat"],
          values: [new_count, repeat_count]
        }
      end

      def visits_distribution_payload
        counts = transactions_for(current_range).group(:customer_id).count.values

        {
          labels: ["1 visit", "2-5 visits", "6+ visits"],
          values: [
            counts.count(1),
            counts.count { |value| value.between?(2, 5) },
            counts.count { |value| value >= 6 }
          ]
        }
      end

      def top_customers_by_transactions_payload
        top_customer_chart_payload(metric: :count)
      end

      def top_customers_by_revenue_payload
        top_customer_chart_payload(metric: :revenue)
      end

      def top_customer_chart_payload(metric:)
        current_entries = top_customers_for(transactions_for(current_range), metric:)
        previous_entries = top_customers_for(transactions_for(previous_range), metric:)
        trend_values = top_customer_trend_values(transactions_for(current_range), current_entries.map { |entry| entry[:customer_id] }, metric:)
        previous_values = top_customer_previous_values(transactions_for(previous_range), current_entries.map { |entry| entry[:customer_id] }, metric:)

        {
          labels: current_entries.map { |entry| entry[:label] },
          values: current_entries.map { |entry| entry[:value] },
          value_type: metric == :revenue ? "currency" : "number",
          items: current_entries.each_with_index.map do |entry, index|
            build_top_customer_item(
              entry:,
              rank: index + 1,
              metric:,
              previous_value: previous_values[entry[:customer_id]],
              trend_values: trend_values[entry[:customer_id]]
            )
          end,
          comparison: chart_comparison_payload(
            current_entries.sum { |entry| entry[:value].to_f },
            previous_entries.sum { |entry| entry[:value].to_f }
          )
        }
      end

      def top_customers_for(scope, metric:)
        grouped_values = case metric
        when :revenue
          scope.group(:customer_id).sum(:fuel_amount)
        else
          scope.group(:customer_id).count
        end

        customers_by_id = Customer.where(id: grouped_values.keys).index_by(&:id)

        grouped_values.filter_map do |customer_id, value|
          customer = customers_by_id[customer_id]
          next if customer.blank?

          {
            customer_id: customer_id,
            label: customer_chart_label(customer),
            value: metric == :revenue ? value.to_f.round(2) : value.to_i
          }
        end
          .sort_by { |entry| [-entry[:value].to_f, entry[:label].downcase] }
          .first(5)
      end

      def top_customer_previous_values(scope, customer_ids, metric:)
        return {} if customer_ids.empty?

        case metric
        when :revenue
          scope.where(customer_id: customer_ids).group(:customer_id).sum(:fuel_amount).transform_values { |value| value.to_f.round(2) }
        else
          scope.where(customer_id: customer_ids).group(:customer_id).count
        end
      end

      def top_customer_trend_values(scope, customer_ids, metric:)
        return {} if customer_ids.empty?

        grouped_values = case metric
        when :revenue
          scope.where(customer_id: customer_ids).group(:customer_id).group("DATE(transactions.created_at)").sum(:fuel_amount)
        else
          scope.where(customer_id: customer_ids).group(:customer_id).group("DATE(transactions.created_at)").count
        end

        values_by_customer = customer_ids.index_with { {} }
        grouped_values.each do |(customer_id, date), value|
          values_by_customer[customer_id][date.to_date] = metric == :revenue ? value.to_f.round(2) : value.to_i
        end

        values_by_customer.transform_values do |series|
          values_for_daily_series(series)
        end
      end

      def build_top_customer_item(entry:, rank:, metric:, previous_value:, trend_values:)
        current_value = entry[:value].to_f
        previous_value = previous_value.to_f

        {
          rank: rank,
          label: entry[:label],
          value: entry[:value],
          display_value: top_customer_display_value(entry[:value], metric:),
          change_label: top_customer_change_label(current_value, previous_value),
          direction: top_customer_direction(current_value, previous_value),
          trend_values: Array(trend_values)
        }
      end

      def top_customer_display_value(value, metric:)
        if metric == :revenue
          display_metric(value, format: :currency)
        else
          count = value.to_i
          "#{display_metric(count, format: :number)} #{count == 1 ? 'visit' : 'visits'}"
        end
      end

      def top_customer_change_label(current_value, previous_value)
        change_pct = percentage_change(current_value, previous_value)
        return "New" if change_pct.nil? && current_value.positive?
        return "0%" if change_pct == 0

        "#{change_pct.positive? ? '+' : ''}#{display_percentage(change_pct)}%"
      end

      def top_customer_direction(current_value, previous_value)
        return "neutral" if previous_value.to_f.zero?

        metric_direction(current_value, previous_value)
      end

      def customer_chart_label(customer)
        name = customer.name.to_s.squish.truncate(18)
        phone_suffix = customer.phone_number.to_s.last(4)

        return name if phone_suffix.blank?
        return customer.phone_number.to_s if name.blank?

        "#{name} - #{phone_suffix}"
      end

      def top_rewards_payload
        counts = point_entries_for(current_range)
          .where(entry_type: :redeem)
          .group(:points)
          .count
          .each_with_object(Hash.new(0)) do |(points, count), grouped|
            grouped[redemption_bucket_for(points)] += count
          end
          .sort_by { |bucket, count| redemption_bucket_sort(bucket, count) }
          .first(5)

        {
          labels: counts.map { |bucket, _count| redemption_bucket_label(bucket) },
          values: counts.map { |_bucket, count| count }
        }
      end

      def rewards_summary
        current_points = point_entries_for(current_range)
        issued = issued_points_total(current_points)
        redeemed = redeemed_points_total(current_points)

        {
          redemption_rate: issued.zero? ? 0.0 : ((redeemed.to_f / issued) * 100).round(1),
          issued_points: issued,
          redeemed_points: redeemed,
          note: "Redemptions are tracked in #{PointsRedeemer::REDEMPTION_INCREMENT}-point slabs. Legacy non-standard entries are grouped under Other."
        }
      end

      def chart_comparison_payload(current_value, previous_value)
        return if current_value.to_f.zero? && previous_value.to_f.zero?

        change_pct = percentage_change(current_value, previous_value)
        if change_pct.nil?
          {
            change_pct: nil,
            direction: "neutral",
            label: "New baseline"
          }
        else
          {
            change_pct: change_pct,
            direction: metric_direction(current_value, previous_value),
            label: "#{change_pct.positive? ? '+' : ''}#{display_percentage(change_pct)}% vs previous #{previous_period_label}"
          }
        end
      end

      def display_percentage(value)
        ApplicationController.helpers.number_with_precision(value, precision: 1, strip_insignificant_zeros: true)
      end

      def previous_period_label
        "#{period_length}-day period"
      end

      def redemption_bucket_for(points)
        absolute_points = points.to_i.abs
        return LEGACY_REDEMPTION_BUCKET if absolute_points.zero?
        return absolute_points if (absolute_points % PointsRedeemer::REDEMPTION_INCREMENT).zero?

        LEGACY_REDEMPTION_BUCKET
      end

      def redemption_bucket_label(bucket)
        return "Other / Legacy" if bucket == LEGACY_REDEMPTION_BUCKET

        "#{bucket} pts"
      end

      def redemption_bucket_sort(bucket, count)
        if bucket == LEGACY_REDEMPTION_BUCKET
          [1, -count, Float::INFINITY]
        else
          [0, -count, bucket]
        end
      end

      def transactions_by_hour_payload
        grouped = transactions_for(current_range).group("EXTRACT(HOUR FROM transactions.created_at)").count

        labels = (0..23).map { |hour| format("%02d:00", hour) }
        values = (0..23).map { |hour| grouped.fetch(hour.to_d, 0) }

        { labels:, values: }
      end

      def transactions_by_day_payload
        grouped = transactions_for(current_range).group("EXTRACT(DOW FROM transactions.created_at)").count

        labels = WEEKDAY_ORDER.values
        values = WEEKDAY_ORDER.keys.map { |dow| grouped.fetch(dow.to_d, 0) }

        { labels:, values: }
      end

      def values_for_daily_series(grouped_values)
        by_date = grouped_values.transform_keys { |key| key.to_date }

        (start_date..end_date).map do |date|
          value = by_date.fetch(date, 0)
          value.is_a?(BigDecimal) ? value.to_f.round(2) : value
        end
      end
    end
  end
end
