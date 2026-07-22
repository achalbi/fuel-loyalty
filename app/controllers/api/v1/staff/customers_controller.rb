module Api
  module V1
    module Staff
      class CustomersController < Api::V1::Staff::BaseController
        LEDGER_PER_PAGE = 5

        # GET /api/v1/staff/customers?q=
        # Blank query -> top 3 by points; else name/phone search (limit 50).
        def index
          authorize Customer, :lookup?
          range = ::Admin::Dashboard::OverviewReport.period_range(
            preset: params[:preset], start_date: params[:start_date], end_date: params[:end_date]
          )
          customer_type = Customer.customer_types.key?(params[:type].to_s) ? params[:type].to_s : nil
          customers = customer_scope(params[:q].to_s.strip, range, customer_type)
          render json: { customers: customers.map { |c| CustomerSummarySerializer.call(c) } }, status: :ok
        end

        # GET /api/v1/staff/customers/lookup?phone_number=
        def lookup
          authorize Customer, :lookup?
          reward_setting = RewardSetting.current
          normalized = Customer.normalize_phone_number(params[:phone_number])

          unless Customer.valid_phone_number?(normalized)
            return render_error(status: 422, code: "invalid_phone",
                                message: "Phone number must be a 10 digit number.")
          end

          customer = Customer.includes(:vehicles).find_by(phone_number: normalized)
          if customer
            render json: CustomerLookupSerializer.call(customer, reward_setting), status: :ok
          else
            render_error(status: :not_found, code: "customer_not_found",
                         message: "Customer not found for that phone number.")
          end
        end

        # GET /api/v1/staff/customers/:id
        def show
          customer = Customer.includes(:vehicles, transactions: %i[user vehicle fuel_pump fuel_pump_nozzle points_ledger])
                             .find(params[:id])
          authorize customer, :show?
          render json: CustomerProfileSerializer.call(customer, RewardSetting.current), status: :ok
        end

        # GET /api/v1/staff/customers/:id/ledger?page=
        def ledger
          customer = Customer.find(params[:id])
          authorize customer, :show?
          page = [params[:page].to_i, 1].max
          total = customer.points_ledgers.count
          entries = customer.points_ledgers
                            .order(created_at: :desc)
                            .offset((page - 1) * LEDGER_PER_PAGE)
                            .limit(LEDGER_PER_PAGE)
          render json: {
            entries: entries.map { |e| LedgerEntrySerializer.call(e) },
            page: page,
            per_page: LEDGER_PER_PAGE,
            total: total,
            has_more: page * LEDGER_PER_PAGE < total,
          }, status: :ok
        end

        # POST /api/v1/staff/customers
        # { name, phone_number, vehicle_number, fuel_type, vehicle_kind, commercial_* }
        # Creates the customer + an initial vehicle atomically.
        def create
          attrs = resource_params(:customer)
          customer = Customer.new(phone_number: Customer.normalize_phone_number(attrs[:phone_number]))
          customer.name = attrs[:name] if attrs[:name].present?
          authorize customer, :create?

          if persist_customer_with_vehicle(customer)
            render json: CustomerProfileSerializer.call(customer.reload, RewardSetting.current), status: :created
          else
            render_validation_error(customer)
          end
        end

        # PATCH /api/v1/staff/customers/:id  { name, phone_number }
        def update
          customer = Customer.find(params[:id])
          authorize customer, :update?
          attrs = resource_params(:customer)
          customer.name = attrs[:name] if attrs.key?(:name)
          customer.phone_number = Customer.normalize_phone_number(attrs[:phone_number]) if attrs.key?(:phone_number)
          customer.customer_type = attrs[:customer_type] if attrs.key?(:customer_type) && Customer.customer_types.key?(attrs[:customer_type].to_s)
          customer.whatsapp_opt_in = ActiveModel::Type::Boolean.new.cast(attrs[:whatsapp_opt_in]) if attrs.key?(:whatsapp_opt_in)
          customer.sms_opt_in = ActiveModel::Type::Boolean.new.cast(attrs[:sms_opt_in]) if attrs.key?(:sms_opt_in)

          if customer.save
            render json: CustomerProfileSerializer.call(customer.reload, RewardSetting.current), status: :ok
          else
            render_validation_error(customer)
          end
        end

        def activate = update_status(active: true)
        def deactivate = update_status(active: false)
        def pause_rewards = update_rewards_paused(paused: true)
        def resume_rewards = update_rewards_paused(paused: false)

        private

        def render_validation_error(record)
          render_error(status: 422, code: "validation_failed",
                       message: record.errors.full_messages.to_sentence.presence || "Validation failed.",
                       details: record.errors.messages)
        end

        def persist_customer_with_vehicle(customer)
          return false unless initial_vehicle_fields_present?(customer)

          success = false
          Customer.transaction do
            raise ActiveRecord::Rollback unless customer.save && save_initial_vehicle(customer)
            success = true
          end
          success
        end

        # Requires vehicle_number/fuel_type/vehicle_kind (name/phone enforced by the model).
        def initial_vehicle_fields_present?(customer)
          attrs = resource_params(:customer)
          customer.valid?
          %i[vehicle_number fuel_type vehicle_kind].each do |field|
            customer.errors.add(field, "can't be blank") if attrs[field].blank?
          end
          customer.errors.none?
        end

        def save_initial_vehicle(customer)
          attrs = resource_params(:customer)
          normalized = Vehicle.normalize_vehicle_number(attrs[:vehicle_number])
          vehicle = customer.vehicles.find_or_initialize_by(vehicle_number: normalized)
          return vehicle if vehicle.persisted?

          vehicle.assign_attributes(
            fuel_type: attrs[:fuel_type],
            vehicle_kind: attrs[:vehicle_kind],
            commercial_company_name: attrs[:commercial_company_name],
            commercial_contact_name: attrs[:commercial_contact_name],
            commercial_contact_phone_number: attrs[:commercial_contact_phone_number],
            commercial_address: attrs[:commercial_address],
            commercial_notes: attrs[:commercial_notes],
          )
          return true if vehicle.save

          vehicle.errors.each { |error| customer.errors.add(error.attribute, error.message) }
          false
        end

        def update_status(active:)
          customer = Customer.find(params[:id])
          authorize customer, active ? :activate? : :deactivate?
          customer.update!(active: active)
          render json: CustomerProfileSerializer.call(customer.reload, RewardSetting.current), status: :ok
        end

        def update_rewards_paused(paused:)
          customer = Customer.find(params[:id])
          authorize customer, paused ? :pause_rewards? : :resume_rewards?
          customer.update!(rewards_paused: paused)
          render json: CustomerProfileSerializer.call(customer.reload, RewardSetting.current), status: :ok
        end

        def customer_scope(query, range = nil, customer_type = nil)
          base = Customer.left_joins(:points_ledgers).includes(:vehicles)
                         .select("customers.*, COALESCE(SUM(points_ledgers.points), 0) AS total_points_sum")
                         .group("customers.id")
          # E2: when a dashboard period is passed, restrict to customers who
          # transacted in it and relax the blank-query top-3 cap so the drilled-in
          # list actually shows the period's customers.
          base = base.where(id: Transaction.where(created_at: range).select(:customer_id)) if range
          # E4: filter by account type (OTP/drive_in/credit).
          base = base.where(customer_type: customer_type) if customer_type

          if query.blank?
            base.order(Arel.sql("COALESCE(SUM(points_ledgers.points), 0) DESC, customers.created_at DESC"))
                .limit(range ? 100 : 3)
          else
            escaped = ActiveRecord::Base.sanitize_sql_like(query)
            normalized_phone = Customer.normalize_phone_number(query)
            conditions = ["customers.name ILIKE :name"]
            values = { name: "%#{escaped}%" }
            if normalized_phone.present?
              conditions << "customers.phone_number LIKE :phone"
              values[:phone] = "%#{normalized_phone}%"
            end
            base.where(conditions.join(" OR "), values)
                .order(Arel.sql("customers.created_at DESC"))
                .limit(50)
          end
        end
      end
    end
  end
end
