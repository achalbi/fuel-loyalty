module Campaigns
  # F1 — a dry run: how many customers currently qualify, a sample, and how many
  # of them are reachable per channel. No grant, no send, no persistence.
  class Preview
    Result = Struct.new(:qualifying_count, :sample, :reachable, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(campaign, reference: Date.current)
      @campaign = campaign
      @reference = reference
    end

    def call
      candidates = Evaluator.new(@campaign, reference: @reference).qualifying
      Result.new(
        qualifying_count: candidates.size,
        sample: candidates.first(10).map do |candidate|
          {
            customer_id: candidate.customer.id,
            name: candidate.customer.display_name,
            aggregated_amount: candidate.amount.to_f,
            aggregated_litres: candidate.litres.to_f,
          }
        end,
        reachable: reachability(candidates)
      )
    end

    private

    # Set-wise so it stays one query for push regardless of audience size (no
    # per-customer reachable_channels N+1). WhatsApp/SMS read the already-loaded
    # opt-in columns.
    def reachability(candidates)
      channels = @campaign.channel_list
      customers = candidates.map(&:customer)
      ids = customers.map(&:id)
      push_ids = channels.include?("push") && ids.any? ? PushSubscription.active.where(customer_id: ids).distinct.pluck(:customer_id).to_set : Set.new

      counts = Hash.new(0)
      customers.each do |customer|
        counts["push"] += 1 if push_ids.include?(customer.id)
        counts["whatsapp"] += 1 if customer.whatsapp_opt_in? && customer.phone_number.present?
        counts["sms"] += 1 if customer.sms_opt_in? && customer.phone_number.present?
      end
      channels.index_with { |channel| counts[channel] }
    end
  end
end
