class ApplicationController < ActionController::Base
  include Pundit::Authorization
  helper_method :pwa_cache_buster

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_private_cache_headers

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

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
end
