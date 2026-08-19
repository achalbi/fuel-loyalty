module Admin
  module Reports
    # E1 — the reporting subsystem. Aggregates the B2 per-visit captures
    # (visit_entries: the source of litres/discount/driver/transporter/vehicle)
    # by a chosen dimension and time grain, deriving ₹ from litres × catalog
    # selling price (LOCKED Q1) and attributing per-customer rewards: the ₹ value
    # of points redemptions (`gifts`) and the count of physical campaign gifts
    # handed over (`gift_count`, F1). Renders JSON or a streamed CSV.
    class LedgerReport
      DIMENSIONS = %w[vehicle transporter driver customer].freeze
      GRAINS = %w[day week month year].freeze
      COLUMNS = %w[key label period litres amount discount gifts gift_count visits].freeze

      # Human headers for the CSV export and the UI tables. The `gifts` KEY is kept
      # as-is so existing API clients don't break, but it reads "Reward ₹" — it has
      # always been the ₹ value of points redemptions, never a gift tally. The
      # physical campaign gifts the operator actually hands over are `gift_count`.
      COLUMN_LABELS = {
        "key" => "Key",
        "label" => "Label",
        "period" => "Period",
        "litres" => "Litres",
        "amount" => "Amount ₹",
        # Discount ₹ is the captured discount only — see the note on
        # `scoped_entries` for why it can read lower than the per-customer
        # `Customer#discount_total` on the admin customer card.
        "discount" => "Discount ₹",
        "gifts" => "Reward ₹",
        "gift_count" => "Gifts",
        "visits" => "Visits",
      }.freeze

      Row = Struct.new(:key, :label, :period, :litres, :amount, :discount, :gifts, :gift_count, :visits, keyword_init: true)

      def initialize(dimension:, grain:, start_date: nil, end_date: nil, preset: nil, fuel_type: nil, fuel_pump_id: nil, customer_id: nil)
        @dimension = DIMENSIONS.include?(dimension.to_s) ? dimension.to_s : "vehicle"
        @grain = GRAINS.include?(grain.to_s) ? grain.to_s : "month"
        @range = resolve_range(preset, start_date, end_date)
        @fuel_type = fuel_type.presence
        @fuel_pump_id = fuel_pump_id.presence
        @customer_id = customer_id.presence
      end

      attr_reader :dimension, :grain, :customer_id

      # The ₹-per-point rate is an operator setting, and RewardSetting#cash_value_for_points
      # returns nil until it is set — so on a pump that never configured one, EVERY
      # redemption stored cash_reward_amount = NULL and the Reward ₹ column is a
      # structural blank rather than a genuine ₹0. Surfaced so web + Android can
      # render "—" and not lie about a zero.
      def reward_value_configured?
        return @reward_value_configured if defined?(@reward_value_configured)

        @reward_value_configured = RewardSetting.current.cash_reward_configured?
      end

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
        lines = [COLUMNS.map { |c| COLUMN_LABELS.fetch(c, c) }]
        rows.each { |r| lines << COLUMNS.map { |c| csv_value(r, c) } }
        lines << ["", "TOTAL", "", totals[:litres], totals[:amount], totals[:discount],
                  csv_reward_value(totals[:gifts]), totals[:gift_count], totals[:visits]]
        lines.map { |cells| cells.map { |cell| csv_field(cell) }.join(",") }.join("\r\n") << "\r\n"
      end

      private

      def csv_value(row, column)
        value = row.public_send(column)
        column == "gifts" ? csv_reward_value(value) : value
      end

      # Same "—" rule the UIs apply: with no ₹-per-point rate configured a zero is
      # structural, not real, so the export must not read as a hard ₹0 either.
      def csv_reward_value(value)
        return "—" if !reward_value_configured? && value.to_d.zero?

        value
      end

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
        gift_counts = gift_count_lookup(buckets)
        @rows = buckets.map do |(key, period), bucket|
          Row.new(
            key: key, label: bucket[:label], period: period,
            litres: bucket[:litres].to_f.round(3),
            amount: bucket[:priced] ? bucket[:amount].to_f.round(2) : nil,
            discount: bucket[:discount].to_f.round(2),
            gifts: gifts_for(bucket, period, gifts).to_f.round(2),
            gift_count: gifts_for(bucket, period, gift_counts).to_i,
            visits: bucket[:visits]
          )
        end.sort_by { |r| [r.label.to_s, r.period] }

        @totals = {
          litres: @rows.sum { |r| r.litres.to_d }.to_f.round(3),
          amount: @rows.sum { |r| r.amount.to_d }.to_f.round(2),
          discount: @rows.sum { |r| r.discount.to_d }.to_f.round(2),
          gifts: @rows.sum { |r| r.gifts.to_d }.to_f.round(2),
          gift_count: @rows.sum(&:gift_count),
          visits: @rows.sum(&:visits),
        }
      end

      def new_bucket
        { label: nil, litres: 0.to_d, amount: 0.to_d, discount: 0.to_d, visits: 0, customer_ids: [], priced: false }
      end

      # The row universe is `visit_entries` and ONLY `visit_entries` — every
      # dimension this report offers (vehicle / transporter / driver / customer)
      # is a column on the capture, and a `transaction` carries none of the first
      # three. So the Discount ₹ column here is `SUM(visit_entries.discount_amount)`
      # flat: it never double-counts (transactions are not summed at all), but it
      # also never sees a standalone counter transaction that was given a discount
      # with no B2 capture behind it.
      #
      # KNOWN DIVERGENCE: `Customer#discount_total` — the per-customer rollup on
      # the admin customer card — DOES pick that transaction up (visit entries,
      # plus any transaction no visit entry points at). So for a customer whose
      # discount lives on a standalone transaction, the card reads higher than
      # this report. Deliberate, not a bug to "fix" by summing transactions here:
      # a standalone transaction has no driver, no transporter and no entry_date,
      # so folding it in would either invent phantom "(none)" rows on three of the
      # four dimensions or inflate the visit count with something that was never
      # captured as a visit. The report answers "what did the captures say", the
      # customer card answers "what did this customer actually get".
      def scoped_entries
        scope = VisitEntry.where(entry_date: date_range).includes(:customer)
        scope = scope.where(fuel_type_code: @fuel_type) if @fuel_type
        scope = scope.where(fuel_pump_id: @fuel_pump_id) if @fuel_pump_id
        scope = scope.where(customer_id: @customer_id) if @customer_id
        scope
      end

      # "Reward ₹" (`gifts`) = ₹ value of points redemptions, bucketed per customer
      # and period, then attributed to each group by its distinct customer set.
      def gift_lookup(buckets)
        lookup = Hash.new(0.to_d)
        customer_ids = buckets.values.flat_map { |b| b[:customer_ids] }.uniq
        return lookup if customer_ids.empty?

        PointsLedger.where(entry_type: :redeem, customer_id: customer_ids, created_at: @range)
          .pluck(:customer_id, :created_at, :cash_reward_amount)
          .each { |cid, at, cash| lookup[[cid, period_key(at.to_date)]] += cash.to_d }
        lookup
      end

      # "Gifts" (`gift_count`) = physical campaign gifts actually handed over. An
      # F1 gift campaign only stamps campaign_qualifications.reward_granted_at — it
      # writes no ledger row and carries no ₹ — so the qualification is the only
      # trace. A qualification is per-CUSTOMER and carries no vehicle/driver/
      # transporter, so only the customer dimension can attribute one; every other
      # dimension reports 0 rather than smearing a customer's gift across the
      # vehicles they happened to fill.
      #
      # Bucketed on `period_start` (the window the customer EARNED it in), not on
      # `reward_granted_at` (when Campaigns::Runner happened to sweep). The runner
      # stamps the grant after the window closes, so a July gift is typically
      # stamped in August — keying on the stamp would report it under August, or
      # drop it entirely, since a row is only counted for a customer who has a
      # visit in that bucket. Qualifying required purchases inside the window, so
      # `period_start` always lands in a period where the customer did fill.
      def gift_count_lookup(buckets)
        lookup = Hash.new(0)
        return lookup unless @dimension == "customer"

        customer_ids = buckets.values.flat_map { |b| b[:customer_ids] }.uniq
        return lookup if customer_ids.empty?

        CampaignQualification.joins(:campaign).merge(Campaign.reward_gift)
          .where(customer_id: customer_ids)
          .where.not(reward_granted_at: nil)
          .where(period_start: date_range)
          .pluck(:customer_id, :period_start)
          .each { |cid, period_start| lookup[[cid, period_key(period_start)]] += 1 }
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
