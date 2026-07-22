class PiiAccessLog < ApplicationRecord
  # A7 — append-only record of a full-Aadhaar / ID-card reveal.
  belongs_to :actor_user, class_name: "User"
  belongs_to :target_user, class_name: "User"

  validates :field, presence: true

  def self.record!(actor:, target:, field:, ip: nil)
    create!(actor_user: actor, target_user: target, field: field, ip: ip)
  end
end
