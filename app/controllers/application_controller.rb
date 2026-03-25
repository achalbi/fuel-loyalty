require "useragent"

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  helper_method :pwa_cache_buster, :customer_points_ledger_path_for, :customer_transaction_history_path_for,
                :firebase_browser_sdk_enabled?, :firebase_web_push_enabled?, :firebase_web_push_settings

  SUPPORTED_BROWSER_VERSIONS = {
    safari: UserAgent::Version.new("16.4"),
    chrome: UserAgent::Version.new("120"),
    firefox: UserAgent::Version.new("121"),
    opera: UserAgent::Version.new("106"),
    ie: false
  }.freeze

  SUPPORTED_SAMSUNG_INTERNET_VERSION = UserAgent::Version.new("24.0")

  # Skip importmap-specific ETag invalidation when this app isn't using config/importmap.rb.
  stale_when_importmap_changes if Rails.root.join("config/importmap.rb").exist?

  before_action :set_private_cache_headers
  before_action :block_unsupported_browser

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def block_unsupported_browser
    return unless unsupported_browser?

    ActiveSupport::Notifications.instrument("browser_block.action_controller", request:, versions: browser_support_policy) do
      render file: Rails.root.join("public/406-unsupported-browser.html"), layout: false, status: :not_acceptable
    end
  end

  def set_private_cache_headers
    response.set_header("Cache-Control", "private, no-store")
  end

  def set_public_cache_headers(max_age:, s_maxage: nil, stale_while_revalidate: nil, stale_if_error: nil, immutable: false)
    directives = ["public", "max-age=#{max_age}"]
    directives << "s-maxage=#{s_maxage}" if s_maxage
    directives << "stale-while-revalidate=#{stale_while_revalidate}" if stale_while_revalidate
    directives << "stale-if-error=#{stale_if_error}" if stale_if_error
    directives << "immutable" if immutable

    response.set_header("Cache-Control", directives.join(", "))
  end

  def user_not_authorized
    redirect_to root_path, alert: "You are not authorized to perform that action."
  end

  def unsupported_browser?
    return false if request.user_agent.blank?

    parsed_browser = parsed_user_agent
    return false if parsed_browser.version.to_s.blank? || parsed_browser.bot?

    !browser_supported?(parsed_browser)
  end

  def browser_supported?(parsed_browser)
    case normalized_browser_name(parsed_browser)
    when "ie"
      false
    when "safari", "firefox", "opera"
      parsed_browser.version >= SUPPORTED_BROWSER_VERSIONS.fetch(normalized_browser_name(parsed_browser).to_sym)
    when "chrome"
      if samsung_internet?
        samsung_internet_version.present? && samsung_internet_version >= SUPPORTED_SAMSUNG_INTERNET_VERSION
      else
        parsed_browser.version >= SUPPORTED_BROWSER_VERSIONS.fetch(:chrome)
      end
    else
      true
    end
  end

  def normalized_browser_name(parsed_browser)
    case parsed_browser.browser.to_s.downcase
    when "internet explorer"
      "ie"
    else
      parsed_browser.browser.to_s.downcase
    end
  end

  def parsed_user_agent
    @parsed_user_agent ||= UserAgent.parse(request.user_agent)
  end

  def samsung_internet?
    request.user_agent.to_s.match?(/SamsungBrowser\//i)
  end

  def samsung_internet_version
    version = request.user_agent.to_s[/SamsungBrowser\/([\d.]+)/i, 1]
    return if version.blank?

    UserAgent::Version.new(version)
  end

  def browser_support_policy
    SUPPORTED_BROWSER_VERSIONS.transform_values { |version| version.is_a?(UserAgent::Version) ? version.to_s : version }
      .merge(samsung_internet: SUPPORTED_SAMSUNG_INTERNET_VERSION.to_s)
  end

  def pwa_cache_buster
    return ENV["RELEASE_SHA"] if ENV["RELEASE_SHA"].present?
    return development_pwa_cache_buster if Rails.env.development?

    Rails.application.config.assets.version
  end

  def development_pwa_cache_buster
    @development_pwa_cache_buster ||= begin
      watched_paths = Dir.glob(
        [
          Rails.root.join("app/assets/**/*").to_s,
          Rails.root.join("app/views/layouts/**/*").to_s,
          Rails.root.join("app/views/pwa/**/*").to_s
        ]
      )

      latest_mtime = watched_paths
        .select { |path| File.file?(path) }
        .map { |path| File.mtime(path).to_i }
        .max

      "dev-#{latest_mtime || Time.current.to_i}"
    end
  end

  def customer_points_ledger_path_for(customer, page: 1)
    if controller_path.start_with?("admin/")
      points_ledger_admin_customer_path(customer, page:)
    else
      points_ledger_customer_path(customer, page:)
    end
  end

  def customer_transaction_history_path_for(customer, page: 1)
    if controller_path.start_with?("admin/")
      transaction_history_admin_customer_path(customer, page:)
    else
      transaction_history_customer_path(customer, page:)
    end
  end

  def firebase_browser_sdk_enabled?
    FirebaseAppConfig.web_configured?
  end

  def firebase_web_push_enabled?
    FirebaseAppConfig.web_push_ready?
  end

  def firebase_web_push_settings
    return {} unless firebase_browser_sdk_enabled?

    {
      firebaseConfig: FirebaseAppConfig.web_config,
      vapidKey: FirebaseAppConfig.vapid_key,
      subscriptionEndpoint: push_subscriptions_path,
      defaultLink: FirebaseAppConfig.notification_link
    }
  end
end
