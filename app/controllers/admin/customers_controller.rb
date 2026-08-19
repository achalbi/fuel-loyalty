module Admin
  class CustomersController < BaseController
    include CustomerPointsLedgerRendering
    include CustomerTransactionHistoryRendering

    # Item 4 — the list is no longer unbounded. It used to render every customer
    # in one page, which was survivable while each row was a plain column read;
    # with six metric subqueries per row it is not.
    CUSTOMERS_PER_PAGE = 25

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
      @customer.info_note_author = current_user

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
      @customer.info_note_author = current_user
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
      # Item 4 — one metrics object per request, shared by the SELECT (display) and
      # the WHERE (thresholds), windowed by the same period the filter bar sets.
      # `points_balance` stays lifetime by design; see the service.
      @customer_metrics = ::Admin::Crm::CustomerMetrics.new(range: @period_range)
      @thresholds = ::Admin::Crm::CustomerMetrics.thresholds_from(params)

      scope = filtered_customers
      @total_customers = scope.count
      @total_pages = @total_customers.zero? ? 1 : (@total_customers.to_f / CUSTOMERS_PER_PAGE).ceil
      @current_page = normalized_page(@total_pages)
      @customers = scope
        .select("customers.*", @customer_metrics.select_sql)
        .order(created_at: :desc, id: :desc)
        .offset((@current_page - 1) * CUSTOMERS_PER_PAGE)
        .limit(CUSTOMERS_PER_PAGE)
        .preload(:vehicles)
        .to_a
      @showing_from = @total_customers.zero? ? 0 : ((@current_page - 1) * CUSTOMERS_PER_PAGE) + 1
      @showing_to = @total_customers.zero? ? 0 : @showing_from + @customers.size - 1
      @customer = form_customer
    end

    # Item 4 — search / status / account type / period AND the six optional
    # thresholds, all resolved by Admin::Crm::CustomerMetrics#cohort so this list
    # and GET /api/v1/admin/customers cannot answer the same question differently.
    # Every threshold is optional and AND-combined; an unset one adds no clause at
    # all, so a customer with zero visits, contacts or points stays reachable.
    # (The period filter used to be `transacted_between` and dropped every
    # visit-entry-only fleet customer — fixed inside #cohort, documented there.)
    def filtered_customers
      @customer_metrics.cohort(
        query: @query,
        status: @current_status,
        customer_type: @current_customer_type,
        thresholds: @thresholds
      )
    end

    def normalized_page(total_pages)
      page = params[:page].to_i
      page = 1 if page < 1
      page = total_pages if page > total_pages
      page
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
      # @crm_insight is present, so the staff surface stays unaffected).
      @crm_insight = ::Admin::Crm::CustomerInsight.new(@customer).to_h
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
