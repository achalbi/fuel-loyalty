module Campaigns
  # F1 — evaluate a campaign, grant each new qualifier its reward, and deliver
  # the offer via the notification engine. Serialized per-campaign with a row
  # lock, and idempotent via reward_granted_at / notified_at so a cron sweep and
  # a manual run in the same window never double-grant or double-notify.
  class Runner
    Result = Struct.new(:qualified, :rewarded, :notification_message, :delivery, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(campaign, notify: true, reference: Date.current)
      @campaign = campaign
      @notify = notify
      @reference = reference
    end

    def call
      # Only an active campaign grants rewards / sends offers (a paused, draft, or
      # completed campaign is a no-op — activate it first).
      return Result.new(qualified: 0, rewarded: 0, notification_message: nil, delivery: {}) unless @campaign.active?

      qualifications = []
      rewarded = 0
      pending_customer_ids = []

      # Read-modify-write only, under the row lock: evaluate, grant, and CLAIM the
      # notification (stamp notified_at) so a concurrent run can't re-dispatch.
      @campaign.with_lock do
        qualifications = Evaluator.new(@campaign, reference: @reference).call
        rewarded = qualifications.count { |qualification| grant_reward(qualification) }
        pending_customer_ids = claim_pending(qualifications)
      end

      # The external channel fan-out (slow HTTP) runs OUTSIDE the lock/transaction
      # so we never hold a row lock or a pooled DB connection across network IO,
      # and an irreversible send is never inside a transaction that could roll back.
      message, delivery = dispatch(pending_customer_ids)
      Result.new(qualified: qualifications.size, rewarded: rewarded, notification_message: message, delivery: delivery)
    end

    private

    def claim_pending(qualifications)
      return [] unless @notify && @campaign.channel_list.any?

      pending = qualifications.reject { |qualification| qualification.notified_at.present? }
      return [] if pending.empty?

      CampaignQualification.where(id: pending.map(&:id)).update_all(notified_at: Time.current, updated_at: Time.current)
      pending.map(&:customer_id)
    end

    def dispatch(customer_ids)
      return [nil, {}] if customer_ids.empty?

      result = Notifications::Broadcaster.call(
        title: @campaign.name,
        body: @campaign.offer_headline,
        category: :offer,
        target_type: "selected",
        customer_ids: customer_ids,
        channels: @campaign.channel_list,
        offer_payload: @campaign.offer_payload,
        campaign: @campaign,
        created_by: @campaign.created_by
      )
      [result.message, result.summary]
    end

    def grant_reward(qualification)
      return false if qualification.rewarded?

      if @campaign.reward_bonus_points?
        grant_bonus_points(qualification)
      else
        # discount / gift are recorded on the qualification; their redemption is
        # the settlement discount pull (D3), not here.
        qualification.update!(reward_granted_at: Time.current)
        true
      end
    end

    def grant_bonus_points(qualification)
      customer = qualification.customer
      return false if customer.rewards_paused? || RewardSetting.current.rewards_paused?

      ledger = customer.points_ledgers.create!(points: @campaign.bonus_points, entry_type: :adjust)
      qualification.update!(reward_granted_at: Time.current, reward_points_ledger_id: ledger.id)
      true
    end
  end
end
