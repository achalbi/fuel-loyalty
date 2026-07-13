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
        ].freeze

        # GET /api/v1/admin/users
        def index
          authorize User, :index?
          users = User.kept.order(:role, :name, :username, :phone_number)
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

        private

        def assign_user_attributes(user, keep_existing_password: false)
          body = resource_params(:user)
          attrs = assignable_attributes(body)
          if keep_existing_password && attrs[:password].blank? && attrs[:password_confirmation].blank?
            attrs.delete(:password)
            attrs.delete(:password_confirmation)
          end
          user.assign_attributes(attrs)
          apply_role(user, body)
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
