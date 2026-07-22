module Admin
  module Crm
    # E6 — lost-customer / churn detection. Flags customers who visited in the
    # *previous* comparable period but NOT the current one ("came last week, not this
    # week", generalized to the selected window), and returns them as a reach-out
    # list sorted by conversion probability so the highest-value follow-ups surface
    # first. Set-based + batch-loaded to stay a handful of queries regardless of size.
    class ChurnReport
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      def initialize(preset: nil, start_date: nil, end_date: nil, page: 1, per_page: DEFAULT_PER_PAGE, as_of: Time.current)
        @preset = preset
        @start_date = start_date
        @end_date = end_date
        @page = [page.to_i, 1].max
        @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
        @as_of = as_of
      end

      def as_json
        rows = sorted_rows
        total = rows.size
        paged = rows.slice((@page - 1) * @per_page, @per_page) || []
        {
          period: { start_date: current_range.begin.to_date, end_date: current_range.end.to_date },
          previous_period: { start_date: previous_range.begin.to_date, end_date: previous_range.end.to_date },
          page: @page,
          per_page: @per_page,
          total: total,
          has_more: @page * @per_page < total,
          customers: paged
        }
      end

      private

      # Lost = visited previous window, absent from current window. If there is no
      # prior data to compare against, nobody is "lost" (avoids flagging everyone in
      # the first period of history).
      def lost_customer_ids
        return @lost_customer_ids if defined?(@lost_customer_ids)

        previous_ids = Customer.active.visited_between(previous_range).pluck(:id)
        current_ids = Customer.visited_between(current_range).pluck(:id).to_set
        @lost_customer_ids = previous_ids.reject { |id| current_ids.include?(id) }
      end

      def sorted_rows
        return [] if lost_customer_ids.empty?

        rows = lost_customer_ids.map { |id| row_for(id) }.compact
        rows.sort_by { |r| [-r[:conversion_probability], -(r[:days_overdue] || 0)] }
      end

      def row_for(id)
        customer = customers_by_id[id]
        return nil if customer.nil?

        cadence = Cadence.call(visit_dates_by_customer[id], as_of: @as_of)
        outcome = last_outcome_by_customer[id]
        probability = ConversionScore.call(cadence: cadence, last_outcome: outcome)

        {
          id: customer.id,
          name: customer.display_name,
          phone_number: customer.phone_number,
          customer_type: customer.customer_type,
          customer_type_label: customer.customer_type_label,
          visit_count: cadence.visit_count,
          last_visited_on: cadence.last_visited_on,
          cadence_class: cadence.cadence_class,
          cadence_label: cadence.cadence_label,
          expected_next_visit_on: cadence.expected_next_visit_on,
          days_overdue: days_overdue(cadence),
          conversion_probability: probability,
          contacts: {
            count: contact_counts_by_customer[id].to_i,
            last_contacted_at: last_contacted_at_by_customer[id],
            last_outcome: outcome
          }
        }
      end

      def days_overdue(cadence)
        reference = cadence.expected_next_visit_on || cadence.last_visited_on
        return nil if reference.nil?

        [(@as_of.to_date - reference).to_i, 0].max
      end

      # ---- batch loads (one query each, scoped to the lost set) ----

      def customers_by_id
        @customers_by_id ||= Customer.where(id: lost_customer_ids).index_by(&:id)
      end

      def visit_dates_by_customer
        return @visit_dates_by_customer if defined?(@visit_dates_by_customer)

        acc = Hash.new { |h, k| h[k] = [] }
        Transaction.where(customer_id: lost_customer_ids).pluck(:customer_id, :created_at)
                   .each { |cid, ts| acc[cid] << ts.to_date }
        VisitEntry.where(customer_id: lost_customer_ids).where.not(entry_date: nil)
                  .pluck(:customer_id, :entry_date)
                  .each { |cid, date| acc[cid] << date }
        @visit_dates_by_customer = acc
      end

      def contact_counts_by_customer
        @contact_counts_by_customer ||= ContactLog.where(customer_id: lost_customer_ids).group(:customer_id).count
      end

      # Most-recent contact_log per customer → its outcome + time.
      def latest_contacts_by_customer
        return @latest_contacts_by_customer if defined?(@latest_contacts_by_customer)

        acc = {}
        ContactLog.where(customer_id: lost_customer_ids)
                  .order(:contacted_at, :id)
                  .pluck(:customer_id, :outcome, :contacted_at)
                  .each { |cid, outcome, at| acc[cid] = { outcome: outcome, contacted_at: at } }
        @latest_contacts_by_customer = acc
      end

      def last_outcome_by_customer
        @last_outcome_by_customer ||= latest_contacts_by_customer.transform_values { |v| v[:outcome] }
      end

      def last_contacted_at_by_customer
        @last_contacted_at_by_customer ||= latest_contacts_by_customer.transform_values { |v| v[:contacted_at] }
      end

      # ---- period ranges ----

      def current_range
        @current_range ||= Admin::Dashboard::OverviewReport.period_range(
          preset: @preset, start_date: @start_date, end_date: @end_date
        ) || default_range
      end

      def default_range
        (Time.current.beginning_of_month..Time.current.end_of_day)
      end

      # The immediately-preceding window of equal length.
      def previous_range
        return @previous_range if defined?(@previous_range)

        start_on = current_range.begin.to_date
        end_on = current_range.end.to_date
        length = (end_on - start_on).to_i + 1
        @previous_range = (start_on - length).beginning_of_day..(start_on - 1).end_of_day
      end
    end
  end
end
