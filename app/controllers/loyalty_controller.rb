class LoyaltyController < ApplicationController
  PUBLIC_CACHE_FALLBACK_TIME = Time.utc(2024, 1, 1).freeze

  # Older cached loyalty shells may still submit POST /loyalty. Keep that
  # compatibility path CSRF-free because it only validates the phone number,
  # mints a short-lived signed lookup token, and redirects to the read-only GET
  # result page.
  skip_forgery_protection only: :create

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
    @phone_number = LoyaltyLookupToken.verified_phone_number(params[:lookup_token])
    return redirect_to(new_loyalty_path, alert: lookup_token_alert) if @phone_number.blank?
    return render_invalid_phone_number unless Customer.valid_phone_number?(@phone_number)

    @customer = Customer.find_by(phone_number: @phone_number)

    if @customer
      # Rotate the token on each render so follow-up navigation doesn't keep
      # reusing the original redirect token.
      @lookup_token = LoyaltyLookupToken.generate(@phone_number)
      @total_points = @customer.total_points
      @redeemable_points = PointsRedeemer.max_redeemable_points(@total_points)
      @points_until_redeemable = [PointsRedeemer::REDEMPTION_INCREMENT - @total_points.to_i, 0].max
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

    redirect_to loyalty_result_path(lookup_token: LoyaltyLookupToken.generate(@phone_number))
  end

  private

  def lookup_token_alert
    if params[:lookup_token].present?
      "That lookup link has expired. Please enter your phone number again."
    else
      "Enter your phone number to continue."
    end
  end

  def render_invalid_phone_number
    flash.now[:alert] = "Phone number must be a 10 digit number."
    render :new, status: :unprocessable_entity
  end

  def loyalty_params
    params.require(:loyalty).permit(:phone_number)
  end
end
