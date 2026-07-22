class LoyaltyController < ApplicationController
  PUBLIC_CACHE_FALLBACK_TIME = Time.utc(2024, 1, 1).freeze
  LOYALTY_LANGUAGE_COOKIE = :loyalty_language
  SUPPORTED_LOYALTY_LOCALES = {
    "en" => "English",
    "kn" => "ಕನ್ನಡ",
    "hi" => "हिन्दी",
    "ta" => "தமிழ்",
    "te" => "తెలుగు",
    "ml" => "മലയാളം",
    "or" => "ଓଡ଼ିଆ",
    "bn" => "বাংলা",
    "mr" => "मराठी",
    "gu" => "ગુજરાતી",
    "pa" => "ਪੰਜਾਬੀ"
  }.freeze

  # Older cached loyalty shells may still submit POST /loyalty. Keep that
  # compatibility path CSRF-free because it only validates the phone number,
  # mints a short-lived signed lookup token, and redirects to the read-only GET
  # result page.
  skip_forgery_protection only: :create
  before_action :discard_devise_sign_out_notice
  before_action :persist_selected_loyalty_language
  before_action :redirect_to_remembered_loyalty_language, only: :new
  around_action :switch_loyalty_locale

  helper_method :loyalty_language_options, :loyalty_language_param, :loyalty_language_params

  def new
    return unless public_loyalty_shell_cacheable?

    theme_setting = ThemeSetting.current
    cache_version = ENV.fetch("RELEASE_SHA", Rails.application.config.assets.version)

    set_public_cache_headers(
      max_age: 0,
      s_maxage: 60,
      stale_while_revalidate: 30,
      stale_if_error: 86_400
    )

    return unless stale?(
      etag: [cache_version, theme_setting.primary_color, I18n.locale],
      last_modified: theme_setting.updated_at&.utc || PUBLIC_CACHE_FALLBACK_TIME,
      public: true
    )
  end

  def show
    @phone_number = LoyaltyLookupToken.verified_phone_number(params[:lookup_token])
    return redirect_to(new_loyalty_path(loyalty_language_params), alert: lookup_token_alert) if @phone_number.blank?
    return render_invalid_phone_number unless Customer.valid_phone_number?(@phone_number)

    @customer = Customer.find_by(phone_number: @phone_number)

    if @customer
      # Rotate the token on each render so follow-up navigation doesn't keep
      # reusing the original redirect token.
      @lookup_token = LoyaltyLookupToken.generate(@phone_number)
      @total_points = @customer.total_points
      @rewards_paused = @customer.rewards_paused?
      @minimum_redeemable_points = @customer.minimum_redeemable_points
      @redeemable_points = @customer.max_redeemable_points
      @points_until_redeemable = @customer.points_until_redeemable
      @full_history = params[:full_history] == "1"
      @activities = @customer.loyalty_activities(limit: @full_history ? nil : 5)
      @show_full_history_button = !@full_history && @customer.loyalty_activities_count > 5
    else
      flash.now[:alert] = t("loyalty.alerts.not_found")
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @phone_number = Customer.normalize_phone_number(loyalty_params[:phone_number])
    return render_invalid_phone_number unless Customer.valid_phone_number?(@phone_number)

    redirect_to loyalty_result_path(loyalty_language_params(lookup_token: LoyaltyLookupToken.generate(@phone_number)))
  end

  # F2 — self-serve WhatsApp/SMS opt-in from the public result card. The phone is
  # taken ONLY from the signed lookup token (never a client-supplied param), so a
  # caller can only change consent for the number they just looked up. CSRF stays
  # on (this is a session form, unlike the cookieless #create shell POST).
  def opt_in
    phone_number = LoyaltyLookupToken.verified_phone_number(params[:lookup_token])
    return redirect_to(new_loyalty_path(loyalty_language_params), alert: lookup_token_alert) if phone_number.blank?

    customer = Customer.find_by(phone_number: phone_number)
    return redirect_to(new_loyalty_path(loyalty_language_params), alert: t("loyalty.alerts.not_found")) if customer.nil?

    saved = customer.update(
      whatsapp_opt_in: truthy_param?(:whatsapp_opt_in),
      sms_opt_in: truthy_param?(:sms_opt_in)
    )

    # Re-issue a fresh lookup token so the result page the customer lands back on
    # can render (and rotate) exactly as a normal view would.
    result_params = loyalty_language_params(lookup_token: LoyaltyLookupToken.generate(phone_number))
    if saved
      redirect_to loyalty_result_path(result_params),
        notice: t("loyalty.optin.saved", default: "Your notification preferences were saved.")
    else
      redirect_to loyalty_result_path(result_params),
        alert: t("loyalty.optin.error", default: "We couldn't save your preferences. Please try again.")
    end
  end

  private

  # Coerce a checkbox param ("1"/"0"/nil) to a strict boolean (never nil, so the
  # NOT NULL opt-in columns are always assigned a real value).
  def truthy_param?(key)
    ActiveModel::Type::Boolean.new.cast(params[key]) || false
  end

  def lookup_token_alert
    if params[:lookup_token].present?
      t("loyalty.alerts.expired_link")
    else
      t("loyalty.alerts.enter_phone")
    end
  end

  def public_loyalty_shell_cacheable?
    # Only cache the anonymous shell. Signed-in chrome and flash banners are
    # session-specific and should never be replayed from a shared cache.
    !user_signed_in? && flash.empty? && !updating_loyalty_language_cookie?
  end

  def render_invalid_phone_number
    flash.now[:alert] = t("loyalty.alerts.invalid_phone")
    render :new, status: :unprocessable_entity
  end

  def switch_loyalty_locale(&action)
    I18n.with_locale(selected_loyalty_locale, &action)
  end

  def selected_loyalty_locale
    normalized_loyalty_locale(params[:lang]) || remembered_loyalty_locale || I18n.default_locale.to_s
  end

  def loyalty_language_options
    SUPPORTED_LOYALTY_LOCALES.map { |locale, label| [label, locale] }
  end

  def loyalty_language_param
    I18n.locale.to_s
  end

  def loyalty_language_params(extra_params = {})
    params = extra_params.compact_blank
    return params if I18n.locale.to_s == I18n.default_locale.to_s

    params.merge(lang: loyalty_language_param)
  end

  def discard_devise_sign_out_notice
    signed_out_messages = [
      I18n.t("devise.sessions.signed_out"),
      I18n.t("devise.sessions.already_signed_out")
    ]

    flash.delete(:notice) if signed_out_messages.include?(flash[:notice])
  end

  def persist_selected_loyalty_language
    selected_locale = normalized_loyalty_locale(params[:lang])
    @updating_loyalty_language_cookie = selected_locale.present? && selected_locale != remembered_loyalty_locale
    return unless updating_loyalty_language_cookie?

    cookies.permanent[LOYALTY_LANGUAGE_COOKIE] = {
      value: selected_locale,
      same_site: :lax
    }
  end

  def redirect_to_remembered_loyalty_language
    return if params[:lang].present?

    remembered_locale = remembered_loyalty_locale
    return if remembered_locale.blank? || remembered_locale == I18n.default_locale.to_s

    redirect_to new_loyalty_path(lang: remembered_locale)
  end

  def remembered_loyalty_locale
    normalized_loyalty_locale(cookies[LOYALTY_LANGUAGE_COOKIE])
  end

  def updating_loyalty_language_cookie?
    @updating_loyalty_language_cookie == true
  end

  def normalized_loyalty_locale(value)
    locale = value.to_s.tr("-", "_")
    return if locale.blank?

    SUPPORTED_LOYALTY_LOCALES.key?(locale) ? locale : nil
  end

  def loyalty_params
    params.require(:loyalty).permit(:phone_number)
  end
end
