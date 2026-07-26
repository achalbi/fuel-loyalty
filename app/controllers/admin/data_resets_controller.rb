module Admin
  # Web-only destructive maintenance screen: preview and then wipe operational
  # transaction data. `show` renders the picker, `create` either re-renders the
  # preview or executes the reset once the confirmation phrase is typed.
  class DataResetsController < BaseController
    DEFAULT_ENTITY_KEYS = %w[transactions points_ledgers].freeze

    def show
      authorize :data_reset, :show?
      @reset = build_reset(entity_keys: DEFAULT_ENTITY_KEYS)
      @counts = @reset.counts
    end

    def create
      authorize :data_reset, :create?
      @reset = build_reset(entity_keys: params[:entities])
      @counts = @reset.counts

      return render :show if params[:mode] != "execute"

      if (@error = execution_error)
        return render :show, status: :unprocessable_entity
      end

      perform_reset
    end

    private

    def build_reset(entity_keys:)
      @customer_lookup_error = nil
      ::Admin::DataReset.new(
        entity_keys: entity_keys,
        start_date: params[:start_date],
        end_date: params[:end_date],
        customer: resolved_customer
      )
    end

    def resolved_customer
      phone = params[:customer_phone].to_s.gsub(/\D/, "")
      return nil if phone.blank?

      customer = Customer.find_by(phone_number: phone)
      @customer_lookup_error = "No customer found with phone number #{phone}." if customer.nil?
      customer
    end

    def execution_error
      return @customer_lookup_error if @customer_lookup_error.present?
      return "Select at least one type of data to reset." unless @reset.entities_selected?
      return nil if params[:confirmation].to_s.strip == ::Admin::DataReset::CONFIRMATION_PHRASE

      "Type #{::Admin::DataReset::CONFIRMATION_PHRASE} in the confirmation box to run the reset."
    end

    def perform_reset
      deleted = @reset.call
      log_reset(deleted)
      redirect_to admin_data_reset_path, notice: reset_summary(deleted)
    end

    def reset_summary(deleted)
      removed = deleted.select { |_key, count| count.positive? }
      return "Nothing matched those filters — no data was deleted." if removed.empty?

      details = removed.map { |key, count| "#{count} #{label_for(key).downcase}" }.to_sentence
      "Reset complete. Deleted #{details}."
    end

    def label_for(key)
      ::Admin::DataReset::ENTITIES_BY_KEY[key]&.label || key.humanize
    end

    def log_reset(deleted)
      Rails.logger.warn(
        "[Admin::DataReset] user_id=#{current_user.id} entities=#{@reset.entity_keys.join(',')} " \
        "start_date=#{@reset.start_date} end_date=#{@reset.end_date} " \
        "customer_id=#{@reset.customer&.id || 'all'} deleted=#{deleted.to_h}"
      )
    end
  end
end
