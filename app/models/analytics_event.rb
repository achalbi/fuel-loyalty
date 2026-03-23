class AnalyticsEvent < ApplicationRecord
  INSTALL_EVENT_NAMES = %w[
    pwa_install_cta_viewed
    pwa_install_prompt_available
    pwa_install_cta_clicked
    pwa_install_manual_instructions_shown
    pwa_install_prompt_shown
    pwa_install_prompt_accepted
    pwa_install_prompt_dismissed
    pwa_install_completed
    pwa_install_prompt_error
  ].freeze

  belongs_to :user, optional: true

  validates :name, presence: true, inclusion: { in: INSTALL_EVENT_NAMES }
  validates :page_path, presence: true

  before_validation :normalize_properties

  private

  def normalize_properties
    self.properties = {} unless properties.is_a?(Hash)
  end
end
