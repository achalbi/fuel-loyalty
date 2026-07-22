module Api
  module V1
    module Admin
      class CampaignSerializer
        def self.call(campaign)
          {
            id: campaign.id,
            name: campaign.name,
            description: campaign.description,
            reward_kind: campaign.reward_kind,
            discount_amount: campaign.discount_amount&.to_f,
            discount_percent: campaign.discount_percent&.to_f,
            gift_description: campaign.gift_description,
            bonus_points: campaign.bonus_points,
            min_purchase_amount: campaign.min_purchase_amount&.to_f,
            min_purchase_litres: campaign.min_purchase_litres&.to_f,
            period: campaign.period,
            period_days: campaign.period_days,
            window_start: campaign.window_start&.iso8601,
            window_end: campaign.window_end&.iso8601,
            target_type: campaign.target_type,
            target_customer_type: campaign.target_customer_type,
            target_customer_ids: campaign.campaign_targets.pluck(:customer_id),
            channels: campaign.channel_list,
            status: campaign.status,
            starts_at: campaign.starts_at&.iso8601,
            ends_at: campaign.ends_at&.iso8601,
            offer_headline: campaign.offer_headline,
            qualification_count: campaign.campaign_qualifications.size,
            created_at: campaign.created_at&.iso8601,
          }
        end
      end
    end
  end
end
