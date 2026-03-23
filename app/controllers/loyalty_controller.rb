class LoyaltyController < ApplicationController
  PUBLIC_CACHE_FALLBACK_TIME = Time.utc(2024, 1, 1).freeze

  def new
    theme_setting = ThemeSetting.current
    cache_version = ENV.fetch("RELEASE_SHA", Rails.application.config.assets.version)

    set_public_cache_headers(
      max_age: 0,
      s_maxage: 60,
      stale_while_revalidate: 30,
      stale_if_error: 86_400
    )

    return unless stale?(
      etag: [cache_version, theme_setting.primary_color],
      last_modified: theme_setting.updated_at&.utc || PUBLIC_CACHE_FALLBACK_TIME,
      public: true
    )
  end

  def show
    @phone_number = Customer.normalize_phone_number(params[:phone_number])
    return render_invalid_phone_number unless Customer.valid_phone_number?(@phone_number)

    @customer = Customer.find_by(phone_number: @phone_number)

    if @customer
      @full_history = params[:full_history] == "1"
      @activities = @customer.loyalty_activities(limit: @full_history ? nil : 5)
      @show_full_history_button = !@full_history && @customer.loyalty_activities_count > 5
    else
      flash.now[:alert] = "No customer found for that phone number."
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @phone_number = Customer.normalize_phone_number(loyalty_params[:phone_number])
    return render_invalid_phone_number unless Customer.valid_phone_number?(@phone_number)

    redirect_to loyalty_result_path(phone_number: @phone_number)
  end

  private

  def render_invalid_phone_number
    flash.now[:alert] = "Phone number must be a 10 digit number."
    render :new, status: :unprocessable_entity
  end

  def loyalty_params
    params.require(:loyalty).permit(:phone_number)
  end
end
