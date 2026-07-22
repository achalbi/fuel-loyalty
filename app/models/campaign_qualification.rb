class CampaignQualification < ApplicationRecord
  # F1 — the period-window aggregation output for one customer: the amount/litres
  # they accumulated, whether the reward was granted (idempotency guard), and
  # whether the offer was delivered. One row per [campaign, customer, period].
  belongs_to :campaign
  belongs_to :customer
  belongs_to :reward_points_ledger, class_name: "PointsLedger", optional: true

  scope :rewardable, -> { where(reward_granted_at: nil) }
  scope :unnotified, -> { where(notified_at: nil) }

  def rewarded?
    reward_granted_at.present?
  end
end
