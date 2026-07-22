module Api
  module V1
    module Admin
      # Richer admin view of a User. Builds on the shared Api::V1::UserSerializer
      # (id, name, username, role, phone_number, display_name, display_phone_number,
      # email, employee_code, subtitle, avatar_initial, active) and adds the audit
      # timestamps the admin CRM lists/detail views expose.
      class UserSerializer
        include Rails.application.routes.url_helpers

        def self.call(user)
          new.call(user)
        end

        # A7 — KYC is MASKED by default. The full Aadhaar and the ID-card URL are
        # NEVER emitted here; they come only from the audited kyc_reveal endpoint.
        def call(user)
          Api::V1::UserSerializer.call(user).merge(
            created_at: user.created_at&.iso8601,
            updated_at: user.updated_at&.iso8601,
            address: user.address,
            aadhaar_present: user.aadhaar_present?,
            aadhaar_masked: user.masked_aadhaar_number,
            profile_photo_url: (rails_blob_path(user.profile_photo, only_path: true) if user.profile_photo.attached?),
            id_card_present: user.id_card_present?,
          )
        end
      end
    end
  end
end
