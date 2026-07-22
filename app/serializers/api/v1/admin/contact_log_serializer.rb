module Api
  module V1
    module Admin
      # E5 — one outreach event.
      class ContactLogSerializer
        def self.call(log)
          {
            id: log.id,
            customer_id: log.customer_id,
            channel: log.channel,
            channel_label: log.channel_label,
            outcome: log.outcome,
            outcome_label: log.outcome_label,
            contacted_role: log.contacted_role,
            customer_contact_id: log.customer_contact_id,
            notes: log.notes,
            logged_by: log.user&.display_name,
            contacted_at: log.contacted_at.iso8601,
          }
        end
      end
    end
  end
end
