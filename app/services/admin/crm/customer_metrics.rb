module Admin
  module Crm
    # Staff feedback item 4 — the admin cohort filter: "customers who have visited
    # us x number of times, who have filled x number of litres, whom I have
    # contacted x number of times, whom we have given x amount of discount, who
    # has accumulated x number of reward points."
    #
    # ONE definition of each of those numbers. Every metric is a correlated scalar
    # subquery over `customers.id`, so the same expression string goes into the
    # SELECT list (to DISPLAY the figure) and into a WHERE (to FILTER on it) —
    # there is no second, divergent definition of "litres filled", and nothing has
    # to load the customer table into Ruby to answer the question.
    #
    # WHY INDEPENDENT SUBQUERIES AND NOT ONE JOIN. Joining transactions,
    # visit_entries, contact_logs and points_ledgers into a single grouped query
    # multiplies the rows against each other: a customer with 3 visits and 2
    # contacts produces 6 rows, and every COUNT/SUM comes back 2x or 3x too big.
    # Each metric therefore aggregates inside its own correlated subquery — two of
    # them for the three de-duplicated fuelling figures — and nothing fans out. The subqueries also COALESCE to 0 instead of dropping the customer, so
    # somebody with no contacts at all is still reachable in the list — LEFT JOIN
    # semantics, not INNER.
    #
    # RECONCILING WITH Campaigns::Evaluator (F1). Campaigns already gate on
    # "min_purchase_litres over a window", and "customers over N litres" must not
    # quietly mean two different things, so the difference is deliberate and named
    # here rather than left to be discovered:
    #
    #   * Campaigns::Evaluator aggregates `transactions` ONLY, and that is right
    #     for a campaign — a campaign REWARDS a purchase, the grant hangs off the
    #     loyalty record, and a fuelling with no loyalty transaction has nothing
    #     to attach a reward to.
    #   * This cohort answers a different question, "who are my customers", and
    #     the whole reason item 4 exists is to find the fleet/OTP/credit accounts
    #     whose fuelling is captured as a visit_entry and never becomes a loyalty
    #     transaction. Aggregating transactions alone would return an empty cohort
    #     for exactly the segment the admin went looking for.
    #
    # So the figures here combine the two sources the way Customer.visited_between
    # does, and both surfaces label them "recorded visits", not "purchases". The
    # follow-up worth doing — out of scope for this change, Campaigns::Evaluator
    # is not ours to edit here — is to move the campaign gate onto these same
    # expressions so a campaign can opt into the union too.
    #
    # ONE DE-DUPLICATION RULE FOR ALL THREE FUELLING FIGURES. visit_count,
    # litres_total and discount_total describe the same events, so they must
    # never disagree about how many events there were. All three go through
    # #deduplicated_aggregate_sql: every captured visit_entry counts, and a
    # transaction counts only when NO visit entry points at it. The rule is the
    # LINK (visit_entries.transaction_id), never the calendar day — see
    # #visit_count_sql for the back-dated pair that made the day rule lie.
    class CustomerMetrics
      # Every metric, in the order both UIs show them.
      METRICS = %i[visit_count litres_total discount_total contact_count points_earned points_balance].freeze

      # metric => the flat query param carrying its threshold. Shared by the web
      # filter form and GET /api/v1/admin/customers so the two accept the same
      # spelling.
      PARAM_KEYS = {
        visit_count: :min_visits,
        litres_total: :min_litres,
        discount_total: :min_discount,
        contact_count: :min_contacts,
        points_earned: :min_points_earned,
        points_balance: :min_points_balance,
      }.freeze

      # metric => the SELECT alias it lands on. `points_balance` keeps the
      # long-standing `total_points_sum` name: Customer#total_points already reads
      # that attribute off a selected row, and it is the identical subquery, so
      # aliasing it anything else would mean computing the same sum twice per row.
      ALIASES = {
        visit_count: "crm_visit_count",
        litres_total: "crm_litres_total",
        discount_total: "crm_discount_total",
        contact_count: "crm_contact_count",
        points_earned: "crm_points_earned",
        points_balance: "total_points_sum",
      }.freeze

      # Litres and rupees take decimals; the rest are whole counts.
      DECIMAL_METRICS = %i[litres_total discount_total].freeze

      STATUS_FILTERS = %w[active inactive].freeze

      # `range` is the Time range from Admin::Dashboard::OverviewReport.period_range
      # (nil = all time). It windows five of the six metrics; `points_balance` is
      # deliberately lifetime — the client asked for BOTH cohorts, "earned x points
      # in this period" and "sits on a balance of x today", because they are
      # different people. See #points_balance_sql.
      def initialize(range: nil)
        @range = range
        @expressions = {}
      end

      attr_reader :range

      # Parses the six optional thresholds off a params hash. A blank, negative or
      # unparseable value is treated as "not asked for" and adds no filter at all.
      def self.thresholds_from(params)
        PARAM_KEYS.each_with_object({}) do |(metric, key), acc|
          raw = params[key]
          next if raw.blank?

          value = cast(raw, decimal: DECIMAL_METRICS.include?(metric))
          next if value.nil? || value.negative?

          acc[metric] = value
        end
      end

      def self.cast(raw, decimal:)
        value = BigDecimal(raw.to_s.strip)
        decimal ? value : value.to_i
      rescue ArgumentError, TypeError
        nil
      end
      private_class_method :cast

      # The inverse of .thresholds_from: turns parsed thresholds back into the
      # flat query params that produced them, so the filter form can re-render
      # what is applied and every chip/pagination link can carry it forward
      # without echoing raw, unvalidated user input. BigDecimal#to_s would emit
      # "0.5e1", hence the "F" format.
      def self.threshold_params(thresholds)
        thresholds.each_with_object({}) do |(metric, value), acc|
          acc[PARAM_KEYS.fetch(metric)] = value.is_a?(Integer) ? value.to_s : value.to_s("F")
        end
      end

      # Reads the metric columns back off a customer loaded with #select_sql.
      # Falls back to zeros for a record selected without them, so a caller can
      # never blow up on a plain Customer.
      def self.values_for(customer)
        {
          visit_count: read(customer, :visit_count).to_i,
          litres_total: read(customer, :litres_total).to_d.to_f.round(3),
          discount_total: read(customer, :discount_total).to_d.to_f.round(2),
          contact_count: read(customer, :contact_count).to_i,
          points_earned: read(customer, :points_earned).to_i,
          points_balance: read(customer, :points_balance).to_i,
        }
      end

      def self.read(customer, metric)
        name = ALIASES.fetch(metric)
        return 0 unless customer.has_attribute?(name)

        customer[name] || 0
      end
      private_class_method :read

      # The metric columns, ready to append to a `select("customers.*", ...)`.
      def select_sql
        METRICS.map { |metric| "#{expression(metric)} AS #{ALIASES.fetch(metric)}" }.join(", ")
      end

      # Raw SQL for one metric. Memoised because the same string is used twice
      # (SELECT + WHERE) per request and each one embeds sanitized range literals.
      def expression(metric)
        @expressions[metric] ||= build_expression(metric)
      end

      # AND-combines the supplied thresholds onto a customers scope. Every one is
      # optional; an unset threshold adds no clause, which is what keeps a
      # customer with zero of that metric reachable.
      def apply(scope, thresholds)
        supplied = thresholds.to_h
        METRICS.reduce(scope) do |acc, metric|
          threshold = supplied[metric]
          next acc if threshold.nil?

          # `>=`, not `>`: "customers who have visited us 5 times" includes the
          # customer who has visited exactly 5 times.
          #
          # Built as an Arel node rather than an interpolated `where` string: the
          # expression is ours (a fixed metric name resolves to a fixed template
          # whose only variable parts are already-sanitized range literals) but
          # interpolating it into a WHERE reads like injection to both Brakeman
          # and the next person, and the threshold binds properly this way.
          acc.where(
            Arel::Nodes::GreaterThanOrEqual.new(
              Arel.sql(expression(metric)), Arel::Nodes.build_quoted(threshold)
            )
          )
        end
      end

      # The whole item-4 cohort in one place: the filters the admin customer list
      # has always had (free-text search, active/inactive, account type, period)
      # plus the item-4 thresholds. Web and API both go through here so the two
      # surfaces cannot drift into returning different cohorts for the same query.
      def cohort(query: nil, status: nil, customer_type: nil, thresholds: {})
        scope = search(Customer.all, query)
        scope = scope.where(active: status == "active") if STATUS_FILTERS.include?(status.to_s)
        # A PERIOD MEANS "ACTIVE IN PERIOD", AND IT GATES EVERY THRESHOLD.
        # This line is not a window on the figures (each expression does its own
        # windowing) — it is a membership test, and it AND-combines with whatever
        # thresholds were asked for. `min_contacts=3&preset=this_month` is
        # therefore "contacted 3 times AND fuelled this month", and a dormant
        # customer sitting on 5,000 lifetime points is NOT in a
        # `min_points_balance` cohort scoped to this month even though
        # points_balance itself is deliberately lifetime.
        #
        # That is kept on purpose, not overlooked: "customers active in this
        # period" is the pre-existing meaning of this date picker everywhere in
        # the admin, and the E2 dashboard drill-through ("N customers this month"
        # → this list) is only correct because of it. What it is NOT allowed to be
        # is a surprise, so both surfaces label the control "active in period",
        # docs/acefuels/20-api-contracts.md §14 spells the interaction out, and
        # customer_metrics_test.rb pins the points_balance case. Drop the period
        # to ask a lifetime question.
        #
        # `visited_between`, not `transacted_between`: the latter is
        # transactions-only, so any date range silently dropped every
        # fleet/OTP/credit customer whose fuelling is captured as a visit_entry
        # and never becomes a loyalty transaction — precisely the segment a litres
        # or discount cohort exists to find. `visited_between` is the
        # transactions ∪ visit_entries union, the same rule cadence, churn and the
        # metric expressions below already use.
        scope = scope.merge(Customer.visited_between(@range)) if @range
        scope = scope.where(customer_type: customer_type.to_s) if Customer.customer_types.key?(customer_type.to_s)
        apply(scope, thresholds)
      end

      private

      # Name / phone / vehicle free-text search, OR-combined (unchanged rules).
      def search(scope, query)
        text = query.to_s.strip
        return scope if text.blank?

        phone_query = Customer.normalize_phone_number(text)
        vehicle_query = Vehicle.normalize_vehicle_number(text)
        conditions = ["LOWER(customers.name) LIKE :name"]
        values = { name: "%#{ActiveRecord::Base.sanitize_sql_like(text.downcase)}%" }

        if phone_query.present?
          values[:phone] = "%#{ActiveRecord::Base.sanitize_sql_like(phone_query)}%"
          conditions << "customers.phone_number LIKE :phone"
        end

        if vehicle_query.present?
          vehicle_like = "%#{ActiveRecord::Base.sanitize_sql_like(vehicle_query)}%"
          values[:legacy_vehicle] = vehicle_like
          values[:vehicle] = vehicle_like
          conditions << "customers.vehicle_number LIKE :legacy_vehicle"
          # A subquery rather than a LEFT JOIN onto vehicles: the join fans a
          # customer out to one row per vehicle, which the old code papered over
          # with `.distinct` — and a DISTINCT list can be neither counted nor paged
          # cleanly once the metric subqueries are in the SELECT.
          conditions << "customers.id IN (SELECT crm_vehicle.customer_id FROM vehicles crm_vehicle WHERE crm_vehicle.vehicle_number LIKE :vehicle)"
        end

        scope.where(conditions.join(" OR "), values)
      end

      def build_expression(metric)
        case metric
        when :visit_count then visit_count_sql
        when :litres_total then deduplicated_sum_sql("litres")
        when :discount_total then deduplicated_sum_sql("discount_amount")
        when :contact_count then contact_count_sql
        when :points_earned then points_earned_sql
        when :points_balance then points_balance_sql
        else raise ArgumentError, "unknown customer metric #{metric.inspect}"
        end
      end

      # "Visited us x number of times" — recorded FUELLINGS, de-duplicated on the
      # LINK. Every captured visit_entry counts once; a loyalty transaction counts
      # only when no visit entry points at it. That is the same anti-join
      # deduplicated_sum_sql uses, so a linked pair is one visit, exactly as it is
      # 20 litres and ₹100 rather than 40 litres and ₹200.
      #
      # WHY NOT DISTINCT DAYS, WHICH IS WHAT THIS USED TO COUNT. The old
      # expression UNIONed visit DAYS, i.e. it de-duplicated a linked pair on the
      # calendar date rather than on the link — which only collapses when both
      # rows happen to land on the same day. A visit entry captured for 30 Jun
      # whose loyalty transaction was written on 1 Jul (back-dated capture: the
      # fleet/OTP/credit workflow visit entries exist for) produced two days and
      # reported TWO visits for one fuelling, while litres_total and
      # discount_total correctly reported it once. Three figures on the same row
      # then contradicted each other about a single event. De-duplicating on the
      # link makes them agree by construction, in every timezone, on every date.
      #
      # The consequence worth naming: two separate fuellings on ONE day are two
      # visits here, whereas Admin::Crm::Cadence — which uniqs a date array
      # because it measures the GAP between visits — sees one day. Different
      # questions ("how often do they come" vs "how many fuellings did we serve"),
      # and this one is the count that has to reconcile with litres and discount.
      def visit_count_sql
        deduplicated_aggregate_sql("COUNT(*)", "COUNT(*)")
      end

      # Item 5's de-duplication rule, in SQL. Customer#discount_total documents it
      # in full and owns the single-customer case; this is its set-wise twin, and
      # customer_metrics_test.rb asserts the two agree on the same customer so
      # they cannot drift apart.
      def deduplicated_sum_sql(column)
        deduplicated_aggregate_sql("SUM(crm_visit.#{column})", "SUM(crm_txn.#{column})")
      end

      # THE de-duplication rule, shared by visit_count, litres_total and
      # discount_total so the three can never tell different stories about one
      # fuelling. Aggregate every visit entry in the window, plus every
      # transaction in the window that NO visit entry points at — because
      # VisitEntryRecorder COPIES the litres and discount onto the loyalty
      # transaction it creates, so touching both tables doubles every linked pair.
      #
      # NOT EXISTS rather than NOT IN is deliberate: a single NULL transaction_id
      # inside a NOT IN makes the whole predicate match no rows at all. The
      # anti-join also carries the SAME window as the visit side, so a back-dated
      # pair straddling the period boundary is counted once — by whichever side
      # falls inside the window — instead of being dropped by both.
      #
      # The two aggregate strings are ours, never user input: the visit side is
      # evaluated against `crm_visit`, the transaction side against `crm_txn`.
      def deduplicated_aggregate_sql(visit_aggregate, transaction_aggregate)
        <<~SQL.squish
          (COALESCE((SELECT #{visit_aggregate}
                     FROM visit_entries crm_visit
                     WHERE crm_visit.customer_id = customers.id#{date_filter('crm_visit.entry_date')}), 0)
           + COALESCE((SELECT #{transaction_aggregate}
                       FROM transactions crm_txn
                       WHERE crm_txn.customer_id = customers.id#{timestamp_filter('crm_txn.created_at')}
                         AND NOT EXISTS (SELECT 1
                                         FROM visit_entries crm_link
                                         WHERE crm_link.transaction_id = crm_txn.id
                                           AND crm_link.customer_id = customers.id#{date_filter('crm_link.entry_date')})), 0))
        SQL
      end

      # E5 outreach attempts — "whom I have contacted x number of times".
      def contact_count_sql
        <<~SQL.squish
          (SELECT COUNT(*)
           FROM contact_logs crm_contact
           WHERE crm_contact.customer_id = customers.id#{timestamp_filter('crm_contact.contacted_at')})
        SQL
      end

      # Points EARNED inside the window. Redeems, expiries and adjustments are
      # excluded on purpose: this is the "how much did they rack up" cohort, and a
      # customer who earned 5,000 and spent them all still belongs in it.
      def points_earned_sql
        <<~SQL.squish
          (SELECT COALESCE(SUM(crm_points.points), 0)
           FROM points_ledgers crm_points
           WHERE crm_points.customer_id = customers.id
             AND crm_points.entry_type = #{PointsLedger.entry_types.fetch('earn')}#{timestamp_filter('crm_points.created_at')})
        SQL
      end

      # Lifetime NET balance — every entry type, never windowed. This is the
      # second half of the client's decision on reward points: the balance a
      # customer is sitting on today is a different cohort from what they earned
      # in a period (someone who earned 5,000 and redeemed the lot has a large
      # `points_earned` and a zero balance), and the admin picks which one they
      # mean. It is also the exact figure the list already showed as "N pts".
      def points_balance_sql
        <<~SQL.squish
          (SELECT COALESCE(SUM(crm_points.points), 0)
           FROM points_ledgers crm_points
           WHERE crm_points.customer_id = customers.id)
        SQL
      end

      # Timestamp columns (transactions, contact_logs, points_ledgers) compare
      # against the range as-is; visit_entries compare on their `entry_date`.
      # Same split Customer.visited_between and Customer#discount_total make.
      def timestamp_filter(column)
        return "" if @range.nil?

        ActiveRecord::Base.sanitize_sql_array([" AND #{column} BETWEEN ? AND ?", @range.begin, @range.end])
      end

      def date_filter(column)
        return "" if @range.nil?

        ActiveRecord::Base.sanitize_sql_array(
          [" AND #{column} BETWEEN ? AND ?", @range.begin.to_date, @range.end.to_date]
        )
      end
    end
  end
end
