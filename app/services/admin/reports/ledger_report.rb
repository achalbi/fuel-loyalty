module Admin
  module Reports
    # E1 — the reporting subsystem. Aggregates the B2 per-visit captures
    # (visit_entries: the source of litres/discount/driver/transporter/vehicle)
    # by a chosen dimension and time grain, deriving ₹ from litres × catalog
    # selling price (LOCKED Q1) and attributing reward "gifts" (₹ value of
    # redemptions) per customer. Renders JSON or a streamed CSV.
    class LedgerReport
      DIMENSIONS = %w[vehicle transporter driver customer].freeze
      GRAINS = %w[day week month year].freeze
      COLUMNS = %w[key label period litres amount discount gifts visits].freeze

      Row = Struct.new(:key, :label, :period, :litres, :amount, :discount, :gifts, :visits, keyword_init: true)

      def initialize(dimension:, grain:, start_date: nil, end_date: nil, preset: nil, fuel_type: nil, fuel_pump_id: nil)
        @dimension = DIMENSIONS.include?(dimension.to_s) ? dimension.to_s : "vehicle"
        @grain = GRAINS.include?(grain.to_s) ? grain.to_s : "month"
        @range = resolve_range(preset, start_date, end_date)
        @fuel_type = fuel_type.presence
        @fuel_pump_id = fuel_pump_id.presence
      end

      attr_reader :dimension, :grain

      def rows
        build
        @rows
      end

      def totals
        build
        @totals
      end

      def date_range
        @range.begin.to_date..@range.end.to_date
      end

      def to_csv
        lines = [COLUMNS]
        rows.each { |r| lines << COLUMNS.map { |c| r.public_send(c) } }
        lines << ["", "TOTAL", "", totals[:litres], totals[:amount], totals[:discount], totals[:gifts], totals[:visits]]
        lines.map { |cells| cells.map { |cell| csv_field(cell) }.join(",") }.join("\r\n") << "\r\n"
      end

      private

      # Minimal RFC-4180 field escaping (quote when the value contains a comma,
      # quote or newline; double any embedded quotes) — avoids the csv stdlib.
      def csv_field(value)
        text = value.to_s
        return text unless text.match?(/[",\r\n]/)

        %("#{text.gsub('"', '""')}")
      end

      def resolve_range(preset, start_date, end_date)
        Admin::Dashboard::OverviewReport.period_range(preset: preset, start_date: start_date, end_date: end_date) ||
          (Time.zone.today.beginning_of_month.beginning_of_day..Time.zone.today.end_of_day)
      end

      def build
        return if defined?(@rows)

        price_map = Product.active.fuel.pluck(:fuel_type_code, :selling_price).to_h
        buckets = Hash.new { |h, k| h[k] = new_bucket }

        scoped_entries.find_each do |entry|
          bucket = buckets[[dimension_key(entry), period_key(entry.entry_date)]]
          bucket[:label] ||= dimension_label(entry)
          bucket[:litres] += entry.litres.to_d
          bucket[:discount] += entry.discount_amount.to_d
          bucket[:visits] += 1
          bucket[:customer_ids] << entry.customer_id if entry.customer_id
          price = price_map[entry.fuel_type_code]
          if price
            bucket[:amount] += entry.litres.to_d * price.to_d
            bucket[:priced] = true
          end
        end

        gifts = gift_lookup(buckets)
        @rows = buckets.map do |(key, period), bucket|
          Row.new(
            key: key, label: bucket[:label], period: period,
            litres: bucket[:litres].to_f.round(3),
            amount: bucket[:priced] ? bucket[:amount].to_f.round(2) : nil,
            discount: bucket[:discount].to_f.round(2),
            gifts: gifts_for(bucket, period, gifts).to_f.round(2),
            visits: bucket[:visits]
          )
        end.sort_by { |r| [r.label.to_s, r.period] }

        @totals = {
          litres: @rows.sum { |r| r.litres.to_d }.to_f.round(3),
          amount: @rows.sum { |r| r.amount.to_d }.to_f.round(2),
          discount: @rows.sum { |r| r.discount.to_d }.to_f.round(2),
          gifts: @rows.sum { |r| r.gifts.to_d }.to_f.round(2),
          visits: @rows.sum(&:visits),
        }
      end

      def new_bucket
        { label: nil, litres: 0.to_d, amount: 0.to_d, discount: 0.to_d, visits: 0, customer_ids: [], priced: false }
      end

      # Deliberately visit-entry-only: this report is the per-visit capture ledger,
      # so a drive-in loyalty customer who only has transactions does not appear
      # here. Their litres/discount live on the customer console instead, via
      # Admin::Crm::CustomerMetrics, which unions both sources.
      def scoped_entries
        scope = VisitEntry.where(entry_date: date_range).includes(:customer)
        scope = scope.where(fuel_type_code: @fuel_type) if @fuel_type
        scope = scope.where(fuel_pump_id: @fuel_pump_id) if @fuel_pump_id
        scope
      end

      # "Gifts" = ₹ value of reward redemptions, bucketed per customer and period,
      # then attributed to each group by its distinct customer set.
      def gift_lookup(buckets)
        customer_ids = buckets.values.flat_map { |b| b[:customer_ids] }.uniq
        return {} if customer_ids.empty?

        lookup = Hash.new(0.to_d)
        PointsLedger.where(entry_type: :redeem, customer_id: customer_ids, created_at: @range)
          .pluck(:customer_id, :created_at, :cash_reward_amount)
          .each { |cid, at, cash| lookup[[cid, period_key(at.to_date)]] += cash.to_d }
        lookup
      end

      def gifts_for(bucket, period, lookup)
        bucket[:customer_ids].uniq.sum { |cid| lookup[[cid, period]] }
      end

      def dimension_key(entry)
        case @dimension
        when "vehicle" then entry.vehicle_number.presence || "(unknown)"
        when "transporter" then entry.transport_name.presence || "(none)"
        when "driver" then entry.driver_name.presence || "(none)"
        when "customer" then entry.customer_id&.to_s || "(anonymous)"
        end
      end

      def dimension_label(entry)
        case @dimension
        when "customer" then entry.customer&.display_name || "Anonymous"
        else dimension_key(entry)
        end
      end

      def period_key(date)
        case @grain
        when "day" then date.iso8601
        when "week" then date.strftime("%G-W%V")
        when "month" then date.strftime("%Y-%m")
        when "year" then date.strftime("%Y")
        end
      end
    end
  end
end
