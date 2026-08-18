module Admin
  class CustomersController < BaseController
    include CustomerPointsLedgerRendering
    include CustomerTransactionHistoryRendering

    def index
      authorize Customer
      load_index_state
    end

    def new
      @customer = Customer.new
      authorize @customer
    end

    def create
      normalized_phone = Customer.normalize_phone_number(customer_params[:phone_number])
      @customer = Customer.new(phone_number: normalized_phone)
      authorize @customer
      @customer.assign_attributes(customer_params.slice(
        :name, :info_note, :customer_type, :transport_name, :approx_vehicle_count,
        :whatsapp_opt_in, :sms_opt_in, :customer_contacts_attributes,
      ))

      if persist_customer_with_vehicle
        redirect_to admin_customer_path(@customer), notice: "Customer created successfully."
      else
        load_index_state(form_customer: @customer)
        render :index, status: :unprocessable_entity
      end
    end

    def show
      @customer = Customer.includes(:vehicles, transactions: %i[user vehicle]).find(params[:id])
      authorize @customer
      prepare_show_state
      render "customers/show"
    end

    def edit
      @customer = Customer.find(params[:id])
      authorize @customer
    end

    def update
      @customer = Customer.includes(:vehicles, transactions: %i[user vehicle]).find(params[:id])
      authorize @customer
      @customer.assign_attributes(customer_params.slice(:name, :phone_number, :customer_type, :whatsapp_opt_in, :sms_opt_in, :transport_name, :approx_vehicle_count, :info_note, :customer_contacts_attributes))
      @customer.phone_number = Customer.normalize_phone_number(customer_params[:phone_number])

      if @customer.save
        redirect_to admin_customer_path(@customer), notice: "Customer updated successfully."
      else
        prepare_show_state(open_edit_modal: true)
        render "customers/show", status: :unprocessable_entity
      end
    end

    def points_ledger
      @customer = Customer.find(params[:id])
      authorize @customer
      render_points_ledger_for(@customer)
    end

    def transaction_history
      @customer = Customer.find(params[:id])
      authorize @customer
      render_transaction_history_for(@customer)
    end

    def destroy
      @customer = Customer.find(params[:id])
      authorize @customer
      @customer.destroy!

      redirect_to admin_customers_path, notice: "Customer removed successfully."
    rescue ActiveRecord::DeleteRestrictionError
      redirect_to admin_customer_path(@customer), alert: "Customer cannot be removed because transaction history exists."
    end

    private

    def load_index_state(form_customer: Customer.new)
      @query = params[:q].to_s.strip
      @current_status = normalized_status_filter
      @current_preset = normalized_preset
      @current_start_date = params[:start_date].to_s.presence
      @current_end_date = params[:end_date].to_s.presence
      @period_range = Admin::Dashboard::OverviewReport.period_range(
        preset: @current_preset, start_date: @current_start_date, end_date: @current_end_date
      )
      @current_customer_type = normalized_customer_type
      @thresholds = ::Admin::Crm::CustomerMetrics.normalize_thresholds(params)
      # Built here, not in the view, so every filter chip and clear link carries
      # the same set forward instead of silently dropping half of it.
      @period_params = { preset: @current_preset, start_date: @current_start_date, end_date: @current_end_date }.compact_blank
      @threshold_params = @thresholds.transform_values(&:to_s)
      @customers = filtered_customers
      @customer = form_customer
    end

    def filters_applied?
      @query.present? || @current_status != "all" || @current_customer_type.present? ||
        @period_range.present? || @thresholds.any?
    end
    helper_method :filters_applied?

    def filtered_customers
      metrics = ::Admin::Crm::CustomerMetrics.new(period_range: @period_range, thresholds: @thresholds)
      # The metrics rollups are 1:1 with customers.id, so they survive the
      # vehicles fan-out + DISTINCT that the search needs.
      scope = metrics.apply(Customer.left_joins(:vehicles).select("customers.*").distinct)

      if @query.present?
        name_query = "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%"
        phone_query = Customer.normalize_phone_number(@query)
        vehicle_query = Vehicle.normalize_vehicle_number(@query)
        conditions = ["LOWER(customers.name) LIKE :name"]
        values = { name: name_query }

        if phone_query.present?
          values[:phone] = "%#{ActiveRecord::Base.sanitize_sql_like(phone_query)}%"
          conditions << "customers.phone_number LIKE :phone"
        end

        if vehicle_query.present?
          vehicle_like = "%#{ActiveRecord::Base.sanitize_sql_like(vehicle_query)}%"
          values[:legacy_vehicle] = vehicle_like
          values[:vehicle] = vehicle_like
          conditions << "customers.vehicle_number LIKE :legacy_vehicle"
          conditions << "vehicles.vehicle_number LIKE :vehicle"
        end

        scope = scope.where(conditions.join(" OR "), values)
      end

      scope = case @current_status
      when "active"
        scope.where(active: true)
      when "inactive"
        scope.where(active: false)
      else
        scope
      end

      # "Active in this period" means served in it — a fleet/OTP customer with
      # visit captures but no loyalty transaction counts, matching the visit
      # definition the metrics above use.
      scope = scope.where("visit_stats.customer_id IS NOT NULL") if @period_range
      scope = scope.where(customer_type: @current_customer_type) if @current_customer_type

      scope.preload(:vehicles).order(created_at: :desc)
    end

    def normalized_customer_type
      type = params[:type].to_s
      Customer.customer_types.key?(type) ? type : nil
    end

    def normalized_status_filter
      status = params[:status].to_s
      %w[all active inactive].include?(status) ? status : "all"
    end

    def normalized_preset
      preset = params[:preset].to_s
      Admin::Dashboard::OverviewReport::QUICK_RANGES.key?(preset) ? preset : nil
    end

    def prepare_show_state(open_edit_modal: false)
      @vehicle = Vehicle.new
      @customer_update_path = admin_customer_path(@customer)
      @customer_edit_modal_open = open_edit_modal
      # E3/E5/E7 CRM panels (admin-only; the shared show view renders them only when
      # @crm_insight is present, so the staff surface stays unaffected). The period
      # carried over from the list narrows the commercial totals to the same window
      # the admin was just looking at.
      @period_range = ::Admin::Dashboard::OverviewReport.period_range(
        preset: normalized_preset, start_date: params[:start_date].to_s.presence, end_date: params[:end_date].to_s.presence
      )
      @crm_insight = ::Admin::Crm::CustomerInsight.new(@customer, range: @period_range).to_h
      @contact_logs = @customer.contact_logs.recent_first.to_a
      @customer_feedbacks = @customer.customer_feedbacks.recent_first.to_a
      @reachable_contacts = @customer.customer_contacts.active.order(:role).to_a
    end

    def customer_params
      params.require(:customer).permit(
        :name,
        :phone_number,
        :vehicle_number,
        :fuel_type,
        :vehicle_kind,
        :customer_type,
        :whatsapp_opt_in,
        :sms_opt_in,
        :transport_name,
        :approx_vehicle_count,
        :info_note,
        :commercial_company_name,
        :commercial_contact_name,
        :commercial_contact_phone_number,
        :commercial_address,
        :commercial_notes,
        customer_contacts_attributes: %i[id role name phone_number contacted notes active _destroy]
      )
    end

    def save_vehicle
      vehicle = @customer.vehicles.find_or_initialize_by(vehicle_number: Vehicle.normalize_vehicle_number(customer_params[:vehicle_number]))
      return vehicle if vehicle.persisted?

      vehicle.assign_attributes(
        fuel_type: customer_params[:fuel_type],
        vehicle_kind: customer_params[:vehicle_kind],
        commercial_company_name: customer_params[:commercial_company_name],
        commercial_contact_name: customer_params[:commercial_contact_name],
        commercial_contact_phone_number: customer_params[:commercial_contact_phone_number],
        commercial_address: customer_params[:commercial_address],
        commercial_notes: customer_params[:commercial_notes]
      )

      vehicle.save.tap do |saved|
        next if saved

        vehicle.errors.each do |error|
          @customer.errors.add(error.attribute, error.message)
        end
      end
    end

    def persist_customer_with_vehicle
      success = false

      Customer.transaction do
        unless @customer.save
          raise ActiveRecord::Rollback
        end

        vehicle_state = initial_vehicle_state
        if vehicle_state == :partial || (vehicle_state == :complete && !save_vehicle)
          raise ActiveRecord::Rollback
        end
        success = true
      end

      success
    end

    def initial_vehicle_state
      values = %i[vehicle_number fuel_type vehicle_kind].map { |field| customer_params[field].presence }
      return :none if values.all?(&:blank?)
      return :complete if values.all?(&:present?)

      %i[vehicle_number fuel_type vehicle_kind].zip(values).each do |field, value|
        next if value.present?

        @customer.errors.add(field, "can't be blank")
      end
      :partial
    end
  end
end
