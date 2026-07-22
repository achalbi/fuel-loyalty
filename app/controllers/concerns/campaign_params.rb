module CampaignParams
  extend ActiveSupport::Concern

  private

  # Assigns permitted attributes to a campaign, translating the array `channels`
  # into the stored comma string and `target_customer_ids` into campaign_targets
  # (added/removed via the autosaved association).
  def assign_campaign(campaign, attributes)
    attrs = attributes.to_h.symbolize_keys
    channels = attrs.delete(:channels)
    target_ids = attrs.delete(:target_customer_ids)

    campaign.assign_attributes(attrs)
    campaign.channels = Array(channels).map { |value| value.to_s.strip }.reject(&:blank?).join(",") unless channels.nil?
    assign_targets(campaign, target_ids) unless target_ids.nil?
  end

  def assign_targets(campaign, ids)
    wanted = Array(ids).map(&:to_i).reject(&:zero?).uniq
    existing = campaign.campaign_targets.reject(&:marked_for_destruction?)

    existing.each { |target| target.mark_for_destruction unless wanted.include?(target.customer_id) }
    (wanted - existing.map(&:customer_id)).each { |customer_id| campaign.campaign_targets.build(customer_id: customer_id) }
  end
end
