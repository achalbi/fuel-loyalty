module Campaigns
  # F1 — aggregate each candidate customer's purchases inside the campaign's
  # period window and select the qualifiers. `qualifying` is a pure dry-run (no
  # writes, powers preview); `call` upserts a campaign_qualification per
  # qualifier, idempotent on [campaign, customer, period_start].
  class Evaluator
    Candidate = Struct.new(:customer, :amount, :litres, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(campaign, reference: Date.current)
      @campaign = campaign
      @reference = reference
      @window = campaign.window_for(reference)             # aggregation window (may slide daily)
      @qualification_period = campaign.qualification_period(reference) # stable idempotency key
    end

    def qualifying
      return [] if @window.nil?

      totals = aggregates
      candidate_customers.filter_map do |customer|
        agg = totals[customer.id] || { amount: 0.to_d, litres: 0.to_d }
        next unless @campaign.thresholds_met?(amount: agg[:amount], litres: agg[:litres])

        Candidate.new(customer: customer, amount: agg[:amount], litres: agg[:litres])
      end
    end

    def call
      qualifying.map { |candidate| upsert(candidate) }
    end

    private

    def candidate_customers
      @candidate_customers ||= Notifications::AudienceResolver.call(
        target_type: @campaign.target_type,
        target_customer_type: @campaign.target_customer_type,
        customer_ids: @campaign.campaign_targets.pluck(:customer_id)
      ).customers.to_a
    end

    # One grouped query over the window, keyed by customer_id.
    def aggregates
      ids = candidate_customers.map(&:id)
      return {} if ids.empty?

      Transaction.where(customer_id: ids, created_at: window_range)
        .group(:customer_id)
        .pluck(Arel.sql("customer_id, COALESCE(SUM(fuel_amount), 0), COALESCE(SUM(litres), 0)"))
        .to_h { |cid, amount, litres| [cid, { amount: amount.to_d, litres: litres.to_d }] }
    end

    def window_range
      @window.begin.beginning_of_day..@window.end.end_of_day
    end

    def upsert(candidate)
      qualification = @campaign.campaign_qualifications.find_or_initialize_by(
        customer_id: candidate.customer.id, period_start: @qualification_period.begin
      )
      qualification.period_end = @qualification_period.end
      qualification.aggregated_amount = candidate.amount
      qualification.aggregated_litres = candidate.litres
      qualification.qualified_at ||= Time.current
      qualification.save!
      qualification
    end
  end
end
