module Admin
  module Crm
    # E3 + E5 — the per-customer CRM profile: visit cadence, recency, a conversion
    # probability, rollups of outreach (contact_logs) and feedback, and the
    # commercial totals (litres, discount given, gifts given) from CustomerMetrics.
    # Computed on read from the visit history; nothing is denormalized on
    # `customers`. `range` narrows the commercial totals to a period; the cadence
    # fields are always full-history.
    class CustomerInsight
      def initialize(customer, as_of: Time.current, range: nil)
        @customer = customer
        @as_of = as_of
        @range = range
      end

      def cadence
        @cadence ||= Cadence.call(visit_dates, as_of: @as_of)
      end

      def conversion_probability
        @conversion_probability ||= ConversionScore.call(cadence: cadence, last_outcome: last_contact&.outcome)
      end

      # Same SQL the admin customers list filters on, so the two can never disagree.
      def metrics
        @metrics ||= CustomerMetrics.for(@customer, period_range: @range)
      end

      def lifetime_metrics
        return metrics if @range.nil?

        @lifetime_metrics ||= CustomerMetrics.for(@customer)
      end

      def to_h
        c = cadence
        {
          customer_id: @customer.id,
          first_visited_on: c.first_visited_on,
          last_visited_on: c.last_visited_on,
          days_since_last_visit: c.days_since_last_visit,
          visit_count: c.visit_count,
          cadence_class: c.cadence_class,
          cadence_label: c.cadence_label,
          median_gap_days: c.median_gap_days,
          expected_next_visit_on: c.expected_next_visit_on,
          is_lost: lost?,
          conversion_probability: conversion_probability,
          metrics: metrics.to_h,
          contacts: contacts_summary,
          feedback: feedback_summary
        }.tap do |data|
          # Only worth carrying when it says something the period totals do not.
          data[:lifetime_metrics] = lifetime_metrics.to_h if @range
        end
      end

      # Cadence-overdue: past the expected next visit. (The churn *list*, E6, uses a
      # period-relative "visited previous period, not this one" rule instead.)
      def lost?
        expected = cadence.expected_next_visit_on
        return false if expected.nil?

        expected < @as_of.to_date
      end

      private

      # Distinct visit days across full history — union of transaction dates and
      # captured visit_entry dates (Customer.visited_between semantics, per-customer).
      def visit_dates
        return @visit_dates if defined?(@visit_dates)

        txn = @customer.transactions.pluck(:created_at).map(&:to_date)
        visits = @customer.visit_entries.where.not(entry_date: nil).pluck(:entry_date)
        @visit_dates = (txn + visits)
      end

      def last_contact
        @last_contact = @customer.contact_logs.recent_first.first unless defined?(@last_contact)
        @last_contact
      end

      def contacts_summary
        {
          count: @customer.contact_logs.count,
          last_contacted_at: last_contact&.contacted_at,
          last_outcome: last_contact&.outcome,
          last_outcome_label: last_contact&.outcome_label
        }
      end

      def feedback_summary
        scope = @customer.customer_feedbacks
        latest = scope.recent_first.first
        {
          count: scope.count,
          avg_rating: scope.average(:rating)&.to_f&.round(2),
          latest_rating: latest&.rating,
          latest_comment: latest&.comment
        }
      end
    end
  end
end
