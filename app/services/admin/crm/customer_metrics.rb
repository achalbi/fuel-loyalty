module Admin
  module Crm
    # E1/E3 — the single definition of a customer's commercial footprint: how
    # often they came, how much fuel they took, how much discount we gave them,
    # how many times we reached out, and the ₹ value of the gifts (reward
    # redemptions) they took. Used two ways off the SAME SQL so the number on the
    # customer list can never disagree with the number on their profile:
    #
    #   * #apply(scope)      — joins the rollups onto a customers scope and applies
    #                          the "at least X" threshold filters.
    #   * #cohort(...)       — #apply plus the list's own filters (search, status,
    #                          type, period), shared by the web admin list and
    #                          GET /api/v1/admin/customers.
    #   * #totals_for(record) — the same rollups for one customer.
    #
    # Counting rules (deliberate, see docs/acefuels/13-spec-customer-crm-capture.md):
    #
    #   * Visits, litres and discount are THREE AGGREGATES OVER ONE STREAM of
    #     fuellings — COUNT(*), SUM(litres), SUM(discount) off the same rows — so
    #     the three figures on a row cannot disagree about how many events they
    #     describe. The de-duplication rule is the LINK, never the calendar day.
    #   * That stream is every transaction PLUS only those visit entries with no
    #     linked transaction. VisitEntryRecorder copies the capture's litres and
    #     discount onto the transaction it creates and back-links it via
    #     visit_entries.transaction_id, so counting both sides of a linked pair
    #     would double every figure.
    #   * Anonymous captures (customer_id IS NULL) belong to nobody and are out.
    #   * Litres, discount, contacts, gifts and points EARNED are FLOWS — scoped to
    #     the selected period. The points BALANCE is a STOCK and stays lifetime,
    #     because that is the number the row displays and the redemption rules use.
    class CustomerMetrics
      # Filter name => how to read it off the query string.
      #
      # "Reward points" has TWO honest readings and the client asked for both, so
      # they are two independent filters rather than one that has to guess which
      # was meant:
      #
      #   * min_points        — the lifetime NET balance the customer sits on today
      #                         (earn - redeem - expire ± adjust). Keeps its
      #                         original spelling: it is the filter the admin list
      #                         has always had, and bookmarks, the dashboard
      #                         drill-through and every chip link carry it.
      #   * min_points_earned — points EARNED (`entry_type: earn` only), inside the
      #                         selected period. "Customers who have accumulated x
      #                         reward points" usually means this one, and it finds
      #                         people the balance filter cannot: earn 5,000, redeem
      #                         4,800, and the balance left to filter on is 200.
      THRESHOLDS = {
        min_visits: :integer,
        min_litres: :decimal,
        min_contacts: :integer,
        min_discount: :decimal,
        min_points: :integer,
        min_points_earned: :integer,
      }.freeze

      # Which selected column each threshold constrains.
      THRESHOLD_COLUMNS = {
        min_visits: "COALESCE(visit_stats.visit_days, 0)",
        min_litres: "COALESCE(visit_stats.litres, 0)",
        min_contacts: "COALESCE(contact_stats.contact_count, 0)",
        min_discount: "COALESCE(visit_stats.discount, 0)",
        min_points: "COALESCE(point_stats.points_balance, 0)",
        min_points_earned: "COALESCE(point_stats.points_earned, 0)",
      }.freeze

      # Bounded by the column precision in db/schema.rb (litres 10,3; amounts
      # 10,2) so an oversized filter value cannot raise a numeric overflow.
      DECIMAL_FORMATS = {
        min_litres: /\A\d{1,6}(\.\d{1,3})?\z/,
        min_discount: /\A\d{1,8}(\.\d{1,2})?\z/,
      }.freeze

      # Counting filters compare against COUNT/SUM columns; anything past this is
      # not a real threshold and would only risk a numeric overflow in Postgres.
      MAX_COUNT = 1_000_000_000

      # Anything else (including "all" and a missing param) means both.
      STATUS_FILTERS = %w[active inactive].freeze

      # `total_points_sum` keeps its long-standing name: Customer#total_points
      # already reads that attribute off a selected row, and it is the identical
      # sum, so aliasing it anything else would compute it twice per row.
      SELECT_COLUMNS = <<~SQL.squish.freeze
        COALESCE(point_stats.points_balance, 0) AS total_points_sum,
        COALESCE(point_stats.points_earned, 0) AS points_earned,
        COALESCE(point_stats.gifts_value, 0) AS gifts_value,
        COALESCE(visit_stats.visit_days, 0) AS visit_days,
        COALESCE(visit_stats.litres, 0) AS litres_filled,
        COALESCE(visit_stats.discount, 0) AS discount_given,
        COALESCE(contact_stats.contact_count, 0) AS contact_count
      SQL

      Totals = Struct.new(:visits, :litres, :discount, :gifts, :contacts, :points, keyword_init: true) do
        def to_h
          { visits: visits, litres: litres, discount: discount, gifts: gifts, contacts: contacts, points: points }
        end
      end

      EMPTY = Totals.new(visits: 0, litres: 0.0, discount: 0.0, gifts: 0.0, contacts: 0, points: 0).freeze

      # Reads the "at least X" filters off the query string, dropping anything
      # blank, non-numeric, negative or too large to compare against the column.
      def self.normalize_thresholds(params)
        THRESHOLDS.each_with_object({}) do |(key, type), result|
          raw = params[key].to_s.strip
          next if raw.blank?

          value = type == :integer ? parse_integer(raw) : parse_decimal(key, raw)
          result[key] = value unless value.nil?
        end
      end

      # Base 10 explicitly: Kernel#Integer would otherwise read "010" as octal and
      # "0x10" as hex, filtering on a number the admin never typed.
      def self.parse_integer(raw)
        value = Integer(raw, 10, exception: false)
        value if value && value.between?(0, MAX_COUNT)
      end
      private_class_method :parse_integer

      def self.parse_decimal(key, raw)
        return nil unless DECIMAL_FORMATS.fetch(key).match?(raw)

        BigDecimal(raw)
      end
      private_class_method :parse_decimal

      def self.for(customer, period_range: nil)
        new(period_range: period_range).totals_for(customer)
      end

      def initialize(period_range: nil, thresholds: {})
        @period_range = period_range
        @thresholds = thresholds.slice(*THRESHOLDS.keys)
      end

      attr_reader :thresholds

      def apply(scope)
        scope = scope.joins(visit_stats_join).joins(contact_stats_join).joins(point_stats_join)
        scope = scope.select(SELECT_COLUMNS)
        @thresholds.each do |key, value|
          scope = scope.where("#{THRESHOLD_COLUMNS.fetch(key)} >= ?", value)
        end
        scope
      end

      # The whole cohort in one place: the filters the admin customer list has
      # always had (free-text search, active/inactive, account type, "active in
      # this period") AND-combined with the "at least X" thresholds #apply adds.
      # The web list and GET /api/v1/admin/customers both come through here, so
      # the two surfaces cannot drift into returning different customers for the
      # same query. Ordering and preloading are the caller's business.
      def cohort(query: nil, status: nil, customer_type: nil)
        scope = search(apply(::Customer.select("customers.*")), query)
        scope = scope.where(active: status.to_s == "active") if STATUS_FILTERS.include?(status.to_s)
        # "Active in this period" means SERVED in it — a fleet/OTP customer with
        # visit captures but no loyalty transaction counts, matching the visit
        # definition the metrics use. The rollup is already windowed to the period,
        # so its presence IS the membership test and no second union is needed.
        # Note this gates every threshold, including the lifetime points balance:
        # a dormant customer sitting on 5,000 points is not "active in July".
        scope = scope.where("visit_stats.customer_id IS NOT NULL") if @period_range
        scope = scope.where(customer_type: customer_type.to_s) if ::Customer.customer_types.key?(customer_type.to_s)
        scope
      end

      def totals_for(record)
        row = apply(::Customer.where(id: record.id)).select("customers.id").first
        return EMPTY if row.nil?

        Totals.new(
          visits: row[:visit_days].to_i,
          litres: row[:litres_filled].to_d.to_f,
          discount: row[:discount_given].to_d.to_f,
          gifts: row[:gifts_value].to_d.to_f,
          contacts: row[:contact_count].to_i,
          points: row[:total_points_sum].to_i
        )
      end

      private

      # Name / phone / vehicle free-text search, OR-combined — the rules the admin
      # list has always used. The vehicle half is a subquery rather than a join
      # onto vehicles: a join fans a customer out to one row per vehicle, which
      # then needs a DISTINCT, and a DISTINCT list can be neither counted nor paged
      # cleanly once the metric columns are in the SELECT.
      def search(scope, query)
        text = query.to_s.strip
        return scope if text.blank?

        phone_query = ::Customer.normalize_phone_number(text)
        vehicle_query = ::Vehicle.normalize_vehicle_number(text)
        conditions = ["LOWER(customers.name) LIKE :name"]
        values = { name: "%#{::ActiveRecord::Base.sanitize_sql_like(text.downcase)}%" }

        if phone_query.present?
          values[:phone] = "%#{::ActiveRecord::Base.sanitize_sql_like(phone_query)}%"
          conditions << "customers.phone_number LIKE :phone"
        end

        if vehicle_query.present?
          vehicle_like = "%#{::ActiveRecord::Base.sanitize_sql_like(vehicle_query)}%"
          values[:legacy_vehicle] = vehicle_like
          values[:vehicle] = vehicle_like
          conditions << "customers.vehicle_number LIKE :legacy_vehicle"
          conditions << "customers.id IN (SELECT crm_vehicles.customer_id FROM vehicles crm_vehicles WHERE crm_vehicles.vehicle_number LIKE :vehicle)"
        end

        scope.where(conditions.join(" OR "), values)
      end

      # One de-duplicated stream of "customer X was served for L litres with ₹
      # discount", aggregated once for the whole query rather than per row. Every
      # transaction counts; a visit entry counts only when NO transaction is linked
      # to it, because VisitEntryRecorder copies the capture's litres and discount
      # onto the transaction it creates. That LINK is the whole de-duplication
      # rule, and visits / litres / discount are three aggregates over these same
      # rows — so a linked pair is one visit of 20 L and ₹100 rather than two
      # visits of 40 L and ₹200, by construction rather than by coincidence.
      #
      # One de-duplicated stream of "customer X was served on day D for L litres
      # with ₹ discount", aggregated once for the whole query rather than per row.
      def visit_stats_join
        sanitize(<<~SQL.squish, transaction_period_binds.merge(visit_entry_period_binds).merge(tz: Time.zone.tzinfo.name))
          LEFT JOIN (
            SELECT served.customer_id,
                   COUNT(DISTINCT served.served_on) AS visit_days,
                   SUM(served.litres) AS litres,
                   SUM(served.discount_amount) AS discount
            FROM (
              SELECT transactions.customer_id,
                     (transactions.created_at AT TIME ZONE 'UTC' AT TIME ZONE :tz)::date AS served_on,
                     COALESCE(transactions.litres, 0) AS litres,
                     transactions.discount_amount AS discount_amount
              FROM transactions
              WHERE transactions.customer_id IS NOT NULL
                #{transaction_period_sql}
              UNION ALL
              SELECT visit_entries.customer_id,
                     visit_entries.entry_date AS served_on,
                     visit_entries.litres,
                     visit_entries.discount_amount
              FROM visit_entries
              WHERE visit_entries.customer_id IS NOT NULL
                AND visit_entries.transaction_id IS NULL
                #{visit_entry_period_sql}
            ) AS served
            GROUP BY served.customer_id
          ) AS visit_stats ON visit_stats.customer_id = customers.id
        SQL
      end

      def contact_stats_join
        sanitize(<<~SQL.squish, contact_period_binds)
          LEFT JOIN (
            SELECT contact_logs.customer_id, COUNT(*) AS contact_count
            FROM contact_logs
            WHERE contact_logs.customer_id IS NOT NULL
              #{contact_period_sql}
            GROUP BY contact_logs.customer_id
          ) AS contact_stats ON contact_stats.customer_id = customers.id
        SQL
      end

      # Three readings of the ledger off ONE pass over it, because they answer
      # three different questions and the admin picks which one they meant:
      #
      #   * points_balance — every entry type, NEVER windowed. The stock the
      #     customer sits on today, and the "N pts" the row already displays.
      #   * points_earned  — `earn` rows only, inside the selected period. What
      #     they racked up, unaffected by anything they have since spent.
      #   * gifts_value    — the ₹ value of `redeem` rows inside the period.
      #
      # A customer who earned 5,000 and redeemed 4,800 has points_earned 5,000 and
      # a balance of 200: min_points_earned finds them, min_points does not, and
      # that is the entire reason both thresholds exist.
      def point_stats_join
        binds = ledger_period_binds.merge(
          earn: ::PointsLedger.entry_types.fetch("earn"),
          redeem: ::PointsLedger.entry_types.fetch("redeem")
        )
        sanitize(<<~SQL.squish, binds)
          LEFT JOIN (
            SELECT points_ledgers.customer_id,
                   SUM(points_ledgers.points) AS points_balance,
                   SUM(
                     CASE
                       WHEN points_ledgers.entry_type = :earn #{ledger_period_sql}
                       THEN points_ledgers.points
                       ELSE 0
                     END
                   ) AS points_earned,
                   SUM(
                     CASE
                       WHEN points_ledgers.entry_type = :redeem #{ledger_period_sql}
                       THEN COALESCE(points_ledgers.cash_reward_amount, 0)
                       ELSE 0
                     END
                   ) AS gifts_value
            FROM points_ledgers
            GROUP BY points_ledgers.customer_id
          ) AS point_stats ON point_stats.customer_id = customers.id
        SQL
      end

      def transaction_period_sql
        @period_range ? "AND transactions.created_at BETWEEN :txn_from AND :txn_to" : ""
      end

      def transaction_period_binds
        return {} unless @period_range

        { txn_from: @period_range.begin, txn_to: @period_range.end }
      end

      def visit_entry_period_sql
        @period_range ? "AND visit_entries.entry_date BETWEEN :entry_from AND :entry_to" : ""
      end

      def visit_entry_period_binds
        return {} unless @period_range

        { entry_from: @period_range.begin.to_date, entry_to: @period_range.end.to_date }
      end

      def contact_period_sql
        @period_range ? "AND contact_logs.contacted_at BETWEEN :contact_from AND :contact_to" : ""
      end

      def contact_period_binds
        return {} unless @period_range

        { contact_from: @period_range.begin, contact_to: @period_range.end }
      end

      def ledger_period_sql
        @period_range ? "AND points_ledgers.created_at BETWEEN :ledger_from AND :ledger_to" : ""
      end

      def ledger_period_binds
        return {} unless @period_range

        { ledger_from: @period_range.begin, ledger_to: @period_range.end }
      end

      def sanitize(sql, binds)
        return sql if binds.empty?

        ::ActiveRecord::Base.sanitize_sql_array([sql, binds])
      end
    end
  end
end
