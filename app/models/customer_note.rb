class CustomerNote < ApplicationRecord
  # B1 — one dated entry in a customer's note log. Append-only by design (staff
  # feedback item 13): a note records what was said and when, so editing or
  # overwriting one would destroy the history it exists to keep. Notes carried
  # over from the old single `info_note` column have no author.
  belongs_to :customer
  belongs_to :author, class_name: "User", optional: true

  before_validation :normalize

  validates :body, presence: true, length: { maximum: 2000 }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def author_label
    author&.display_name || "Earlier note"
  end

  private

  def normalize
    self.body = body.to_s.strip.presence
  end
end
