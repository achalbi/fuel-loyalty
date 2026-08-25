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

      # Free-text lookups the operator types rather than picks: which of the four
      # visit-entry identity columns each one searches, and how the typed text has
      # to be normalized first. VisitEntry#normalize_fields stores vehicle numbers
      # as A-Z0-9 only and phone numbers as digits only, so "KA-01 AA 0001" or
      # "98765 43210" would match NOTHING unless the query is put through the same
      # normalizer. Names are stored as typed, so they search raw.
      TEXT_FILTERS = {
        transporter: { column: :transport_name, normalizer: nil },
        driver_name: { column: :driver_name, normalizer: nil },
        driver_phone: {
          column: :driver_phone_number,
          # VisitEntry validates the column as exactly 10 digits, so a mobile typed
          # with a dialling prefix ("+91 98765 43210" → 12 digits) could never match
          # a stored value. Strip a leading 91/0 only when the query is exactly that
          # much longer — a genuine 10-digit-or-shorter partial never is, so a
          # search for numbers merely containing "91" is left alone.
          normalizer: ->(v) { ::Customer.normalize_phone_number(v).sub(/\A(?:0|91)(?=\d{10}\z)/, "") },
        },
        vehicle_number: { column: :vehicle_number, normalizer: ->(v) { ::Vehicle.normalize_vehicle_number(v) } },
      }.freeze

      def initialize(dimension:, grain:, start_date: nil, end_date: nil, preset: nil, fuel_type: nil, fuel_pump_id: nil,
                     customer_id: nil, transporter: nil, driver_name: nil, driver_phone: nil, vehicle_number: nil)
        @dimension = DIMENSIONS.include?(dimension.to_s) ? dimension.to_s : "vehicle"
        @grain = GRAINS.include?(grain.to_s) ? grain.to_s : "month"
        @range = resolve_range(preset, start_date, end_date)
        @fuel_type = fuel_type.presence
        @fuel_pump_id = fuel_pump_id.presence
        @customer_id = customer_id.presence
        @text_filters = normalize_text_filters(
          transporter: transporter, driver_name: driver_name,
          driver_phone: driver_phone, vehicle_number: vehicle_number
        )
      end

      attr_reader :dimension, :grain, :customer_id

      # The normalized text each filter actually searched on — echoed back into the
      # web form and the JSON payload so the operator sees what was queried rather
      # than what they typed (a plate typed "ka 01" really did search "KA01").
      def transporter = @text_filters[:transporter]
      def driver_name = @text_filters[:driver_name]
      def driver_phone = @text_filters[:driver_phone]
      def vehicle_number = @text_filters[:vehicle_number]

      # True when any lookup narrows the report beyond its date range — used both
      # for the "clear filters" affordance and for the gift-row rule below.
      def filtered?
        @text_filters.any? || @fuel_type.present? || @fuel_pump_id.present? || @customer_id.present?
      end

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

        # Gift counts are resolved BEFORE the ₹ lookup, because a granted gift can
        # materialise a customer/period row no visit entry produced (see
        # materialize_gift_rows) and that row must carry its Reward ₹ too.
        gift_counts = gift_count_lookup
        materialize_gift_rows(buckets, gift_counts)
        gifts = gift_lookup(buckets)
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

      # Deliberately visit-entry-only: this report is the per-visit capture ledger,
      # so a drive-in loyalty customer who only has transactions does not appear
      # here. Their litres/discount live on the customer console instead, via
      # Admin::Crm::CustomerMetrics, which unions both sources.
      def scoped_entries
        scope = VisitEntry.where(entry_date: date_range).includes(:customer)
        scope = scope.where(fuel_type_code: @fuel_type) if @fuel_type
        scope = scope.where(fuel_pump_id: @fuel_pump_id) if @fuel_pump_id
        scope = scope.where(customer_id: @customer_id) if @customer_id
        @text_filters.each { |name, value| scope = contains(scope, TEXT_FILTERS.fetch(name)[:column], value) }
        scope
      end

      # Substring, case-insensitive, AND-combined across the four lookups — the
      # operator is narrowing one report ("Rao driving for NL Roadways"), not
      # OR-searching for anything that matches, which is why this differs from the
      # single-box customer search in Admin::Crm::CustomerMetrics#search.
      # LOWER() on both sides so a legacy row saved before VisitEntry#normalize_fields
      # upcased plates still matches. Built through Arel rather than an interpolated
      # SQL string so the column name can never become a query fragment.
      def contains(scope, column, value)
        lowered = Arel::Nodes::NamedFunction.new("LOWER", [VisitEntry.arel_table[column]])
        pattern = "%#{::ActiveRecord::Base.sanitize_sql_like(value.downcase)}%"
        scope.where(lowered.matches(pattern, nil, true))
      end

      # Drops blank lookups and puts the rest through the same normalizer that
      # wrote the column. A typed value that normalizes away entirely (say a plate
      # of "--") is deliberately KEPT as the raw text: it then matches no
      # normalized row and the report reads "no captures", which is the truth —
      # dropping it would silently show every row as if it had matched.
      def normalize_text_filters(**values)
        values.each_with_object({}) do |(name, raw), filters|
          text = raw.to_s.strip
          next if text.blank?

          normalizer = TEXT_FILTERS.fetch(name)[:normalizer]
          filters[name] = (normalizer ? normalizer.call(text).presence : nil) || text
        end
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
      # WHICH period a gift is billed to depends on the campaign's period kind,
      # because `period_start` means two different things — see
      # Campaign#qualification_period:
      #
      # * weekly / monthly — the stored [period_start, period_end] IS a calendar
      #   aggregation window no longer than a report bucket, so `period_start` is
      #   the period the customer EARNED it in. Billed there rather than on
      #   `reward_granted_at` (when Campaigns::Runner happened to sweep): the runner
      #   stamps the grant after the window closes, so a July gift is typically
      #   stamped in August, and keying on the stamp would report it under August.
      # * rolling_days (the DEFAULT the admin new-campaign form ships) and
      #   fixed_window — `period_start` is NOT a usable bucket. For a rolling
      #   campaign Campaign#qualification_period returns
      #   `(rolling_anchor_date..reference)` where the anchor is
      #   `starts_at || created_at`: a FIXED idempotency key, so a window that slides
      #   daily grants once per campaign rather than once per sweep. Billing on it
      #   charges the gift to the campaign's start date — arbitrarily long before the
      #   purchases that earned it. `fixed_window` has the same problem for any promo
      #   longer than a report bucket (the model bounds only start <= end).
      #   These bill on `reward_granted_at`.
      #
      # `period_end` would be the natural window-close for those two, but it is NOT
      # stable: Campaigns::Evaluator#upsert re-assigns it on EVERY sweep the customer
      # still qualifies for (evaluator.rb, unconditional, with no `rewarded?` guard),
      # so a long-running rolling campaign would keep moving an already-granted
      # gift's billed period forward. `reward_granted_at` is written exactly once —
      # Runner#grant_reward returns early on `qualification.rewarded?` — and is
      # literally the day the operator handed the gift over.
      #
      # Every rule derives the billing date from the qualification alone, never from
      # the report range, so one grant is billed to exactly one period and two
      # adjacent reports can never both claim it.
      def gift_count_lookup
        lookup = Hash.new(0)
        return lookup unless @dimension == "customer"

        granted = CampaignQualification.joins(:campaign).merge(Campaign.reward_gift).where.not(reward_granted_at: nil)
        granted = granted.where(customer_id: @customer_id) if @customer_id

        granted.merge(Campaign.where(period: %i[weekly monthly])).where(period_start: date_range)
          .pluck(:customer_id, :period_start)
          .each { |cid, earned_on| lookup[[cid, period_key(earned_on)]] += 1 }

        granted.merge(Campaign.where(period: %i[rolling_days fixed_window]))
          .where(reward_granted_at: @range)
          .pluck(:customer_id, :reward_granted_at)
          .each { |cid, granted_at| lookup[[cid, period_key(granted_at.to_date)]] += 1 }

        lookup
      end

      # Campaigns::Evaluator qualifies customers off `transactions`, while every row
      # of this report is built from `visit_entries` (see scoped_entries), and
      # `gifts_for` only credits a customer a bucket already lists. So a drive-in
      # customer who qualified purely through transactions has no bucket to hang
      # their gift on and it would be counted NOWHERE — the totals silently
      # under-reporting gifts the operator really did hand over. Same hole whenever
      # the billed period holds no capture for that customer (a fixed_window
      # straddling two months; a day grain where the window start is not a fill day).
      #
      # So a counted gift materialises its own customer/period row: zero litres,
      # zero visits, blank amount, the gift on it. It reads as "no capture in this
      # period, but a gift went out" — exactly what the ledger knows.
      #
      # The one exception is a report narrowed by fuel_type, fuel_pump_id, or any of
      # the four free-text lookups (transporter / driver / driver phone / vehicle).
      # A qualification carries none of those, so a gift cannot be said to belong to
      # that slice and inventing a row inside it would assert something the data
      # does not support; gifts for customers who DO have captures in the slice are
      # still counted. `customer_id` is NOT an exception — a qualification does
      # carry a customer, so gift_count_lookup filters on it directly.
      # Called out in docs/acefuels/15-spec-dashboard-reports.md.
      def materialize_gift_rows(buckets, gift_counts)
        return if gift_counts.empty? || @fuel_type || @fuel_pump_id || @text_filters.any?

        missing = gift_counts.keys.reject { |customer_id, period| buckets.key?([customer_id.to_s, period]) }
        return if missing.empty?

        customers = Customer.where(id: missing.map(&:first).uniq).index_by(&:id)
        missing.each do |customer_id, period|
          bucket = buckets[[customer_id.to_s, period]]
          bucket[:label] = customers[customer_id]&.display_name || "Customer ##{customer_id}"
          bucket[:customer_ids] << customer_id
        end
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
