module Api
  module V1
    module Admin
      # Admin CRM users endpoints (mirrors the web Admin::UsersController).
      # Operates on User.kept (Discard soft-delete excluded). Role is applied
      # explicitly (only when present); password is left untouched on update when
      # blank. Uniqueness + the "keep at least one admin" guard are enforced by the
      # User model and surface as 422 via ActiveRecord::RecordInvalid.
      class UsersController < Api::V1::Admin::BaseController
        # Mass-assignable attributes. :role is handled separately (see #apply_role)
        # to match the web, where role is permitted and applied out-of-band.
        ASSIGNABLE_KEYS = %i[
          name username phone_number email active
          password password_confirmation employee_code subtitle
          address aadhaar_number
        ].freeze

        # GET /api/v1/admin/users — active accounts first (User.admin_listing,
        # shared with the web index so the ordering cannot drift).
        def index
          authorize User, :index?
          users = User.admin_listing
          render json: { users: users.map { |u| Api::V1::Admin::UserSerializer.call(u) } }, status: :ok
        end

        # GET /api/v1/admin/users/:id
        def show
          user = User.kept.find(params[:id])
          authorize user, :show?
          render json: Api::V1::Admin::UserSerializer.call(user), status: :ok
        end

        # POST /api/v1/admin/users
        def create
          user = User.new
          authorize user, :create?
          assign_user_attributes(user)
          user.save!
          render json: Api::V1::Admin::UserSerializer.call(user), status: :created
        end

        # PATCH /api/v1/admin/users/:id  (blank password keeps the existing one)
        def update
          user = User.kept.find(params[:id])
          authorize user, :update?
          assign_user_attributes(user, keep_existing_password: true)
          user.save!
          render json: Api::V1::Admin::UserSerializer.call(user), status: :ok
        end

        # GET /api/v1/admin/users/:id/kyc_reveal — audited full-Aadhaar + ID-card.
        def kyc_reveal
          user = User.kept.find(params[:id])
          authorize user, :view_aadhaar?
          PiiAccessLog.record!(actor: current_user, target: user, field: "aadhaar+id_card", ip: request.remote_ip)
          render json: {
            aadhaar_number: user.aadhaar_number,
            id_card_photo_url: blob_path(user.id_card_photo),
            profile_photo_url: blob_path(user.profile_photo),
          }, status: :ok
        end

        # DELETE /api/v1/admin/users/:id/kyc — purge KYC, keep the account.
        def destroy_kyc
          user = User.kept.find(params[:id])
          authorize user, :purge_kyc?
          user.purge_kyc!
          render json: Api::V1::Admin::UserSerializer.call(user.reload), status: :ok
        end

        private

        def assign_user_attributes(user, keep_existing_password: false)
          body = resource_params(:user)
          attrs = assignable_attributes(body)
          if keep_existing_password && attrs[:password].blank? && attrs[:password_confirmation].blank?
            attrs.delete(:password)
            attrs.delete(:password_confirmation)
          end
          # A7: a blank/absent Aadhaar keeps the stored value (parallel to password);
          # clearing is done via the purge endpoint, not an empty edit.
          attrs.delete(:aadhaar_number) if attrs[:aadhaar_number].blank?
          user.assign_attributes(attrs)
          apply_role(user, body)
          attach_kyc_images(user, body)
        end

        # Multipart images ride alongside the scalar params; omitting a part keeps
        # the existing attachment.
        def attach_kyc_images(user, body)
          user.profile_photo.attach(body[:profile_photo]) if body[:profile_photo].respond_to?(:content_type)
          user.id_card_photo.attach(body[:id_card_photo]) if body[:id_card_photo].respond_to?(:content_type)
        end

        def blob_path(attachment)
          return nil unless attachment.attached?

          Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
        end

        # Only the keys the client actually sent, so absent params never clobber
        # existing values (or the DB default for :active on create).
        def assignable_attributes(body)
          ASSIGNABLE_KEYS.each_with_object({}) do |key, attrs|
            attrs[key] = body[key] if body.key?(key)
          end
        end

        # Role is set only when present (matches web role_param handling). The enum
        # is declared with validate: true, so an unknown value fails validation
        # (422) rather than raising ArgumentError on assignment.
        def apply_role(user, body)
          user.role = body[:role] if body[:role].present?
        end
      end
    end
  end
end
