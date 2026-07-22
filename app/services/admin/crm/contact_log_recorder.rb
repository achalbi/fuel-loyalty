module Admin
  module Crm
    # E5 — persists one outreach event and ties it back to the B1 roster: a
    # successful outreach flips the reached person's `contacted` marker (the model
    # stamps contacted_at). Shared by the admin API and the web console. Raises
    # ActiveRecord::RecordInvalid on validation failure (callers render 422 / re-show).
    class ContactLogRecorder
      REACHED_OUTCOMES = %w[reached converted callback_requested].freeze

      def self.call(customer:, user:, attrs:)
        log = customer.contact_logs.new(attrs)
        log.user = user
        # Only a contact that belongs to this customer.
        if log.customer_contact_id.present?
          log.customer_contact = customer.customer_contacts.find_by(id: log.customer_contact_id)
        end
        log.save!
        mark_reached(log)
        log
      end

      def self.mark_reached(log)
        return unless log.customer_contact && REACHED_OUTCOMES.include?(log.outcome)
        return if log.customer_contact.contacted?

        log.customer_contact.update!(contacted: true)
      end
    end
  end
end
