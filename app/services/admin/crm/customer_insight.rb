module Admin
  module Crm
    # E3 + E5 — the per-customer CRM profile: visit cadence, recency, a conversion
    # probability, rollups of outreach (contact_logs) and feedback, the
    # commercial totals (litres, discount given, gifts given) from CustomerMetrics,
    # and the all-time `rewards` rollup (staff feedback item 5).
    # Computed on read from the visit history; nothing is denormalized on
    # `customers`. `range` narrows the commercial totals to a period; the cadence
    # fields and the rewards rollup are always full-history.
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
          feedback: feedback_summary,
          rewards: rewards_summary
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

      # Item 5 — "show up discount amount paid, or gifts given for that customer".
      # Deliberately three separate figures rather than one blended "rewards"
      # number, because they are three different things in three different units:
      #
      # * `discount_total` — ₹ knocked off at the pump. Customer#discount_total
      #   owns the de-duplication of the visit-entry/transaction pair; this reuses
      #   it rather than restating the rule and risking a second answer.
      # * `redemption_*` — points cashed in: the ₹ value, the points, the count.
      # * `gift_count` / `gift_descriptions` — physical F1 campaign gifts actually
      #   handed over, and WHAT they were (the client asked for the item, not just
      #   a tally). These carry no ₹ at all, which is why they are not folded into
      #   `redemption_value`.
      #
      # All-time regardless of `@range`: "what has this customer ever been given"
      # is the question, and a gift handed over last quarter did not un-happen
      # because the admin picked this month. The windowed view of the same money
      # is `metrics[:discount]` / `metrics[:gifts]`.
      def rewards_summary
        redemptions = @customer.points_ledgers.where(entry_type: :redeem)
        gifts = granted_gift_descriptions
        {
          discount_total: @customer.discount_total.to_f.round(2),
          redemption_value: redemptions.sum(:cash_reward_amount).to_f.round(2),
          # Redeem rows store points NEGATIVE (PointsRedeemer); report the magnitude.
          redemption_points: redemptions.sum("ABS(points)").to_i,
          redemption_count: redemptions.count,
          gift_count: gifts.size,
          # The tally is `gift_count`; this list answers "what did we hand over",
          # so a gift won three times is named once.
          gift_descriptions: gifts.compact_blank.uniq,
          reward_value_configured: reward_value_configured?
        }
      end

      # A granted F1 gift writes no ledger row and carries no ₹ — the stamped
      # `campaign_qualifications.reward_granted_at` is its only trace, so a
      # qualification the customer earned but was never handed does not count.
      # Same predicate LedgerReport#gift_count_lookup counts gifts with, so the
      # reports page and this card cannot disagree about what a gift is. One row
      # per gift, newest first, so the descriptions read newest-received first
      # once de-duplicated.
      def granted_gift_descriptions
        @granted_gift_descriptions ||= @customer.campaign_qualifications
          .joins(:campaign).merge(::Campaign.reward_gift)
          .where.not(reward_granted_at: nil)
          .order(reward_granted_at: :desc)
          .pluck("campaigns.gift_description")
      end

      # With no ₹-per-point rate ever set, EVERY redemption stored
      # cash_reward_amount = NULL, so `redemption_value` sums to a structural 0.
      # Surfaced so web and Android render "—" instead of a ₹0.00 that reads as
      # "we gave them nothing". Reuses the predicate the reports page already
      # applies (Admin::Reports::LedgerReport#reward_value_configured?).
      def reward_value_configured?
        return @reward_value_configured if defined?(@reward_value_configured)

        @reward_value_configured = RewardSetting.current.cash_reward_configured?
      end
    end
  end
end
