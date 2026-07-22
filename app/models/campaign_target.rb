class CampaignTarget < ApplicationRecord
  # F2 — a hand-picked recipient of an individual/selected campaign.
  belongs_to :campaign
  belongs_to :customer

  validates :customer_id, uniqueness: { scope: :campaign_id }
end
