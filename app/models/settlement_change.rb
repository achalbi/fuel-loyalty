class SettlementChange < ApplicationRecord
  # D9 audit trail — one append-only row per admin edit of a submitted/reconciled
  # settlement. Mirrors AttendanceEntryChange: a required change_reason plus a
  # field-level diff. `recomputed_points` records whether the edit reversed and
  # re-awarded loyalty points (C5 ⇄ D9).
  belongs_to :daily_settlement
  belongs_to :changed_by, class_name: "User"

  validates :change_reason, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
